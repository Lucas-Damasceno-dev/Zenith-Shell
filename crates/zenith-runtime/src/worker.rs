//! Background Worker ThreadPool and Asynchronous Task Engine for Zenith Luau.
//!
//! Provides non-blocking concurrency for heavy operations (process execution,
//! delayed timers, I/O tasks) communicating via MPSC channels with the main UI thread.

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Duration;

/// Result returned from an asynchronous background task.
#[derive(Debug, Clone)]
pub enum TaskOutput {
    /// Command execution output: (stdout, stderr, exit_code)
    Process {
        stdout: String,
        stderr: String,
        exit_code: i32,
    },
    /// Generic string or json payload
    Text(String),
    /// Timer elapsed or empty completion
    Empty,
}

/// Completion payload sent from worker thread to the main event loop.
#[derive(Debug)]
pub struct TaskCompletion {
    pub task_id: u64,
    pub result: Result<TaskOutput, String>,
}

enum Job {
    SpawnProcess {
        task_id: u64,
        command: String,
        args: Vec<String>,
    },
    Delay {
        task_id: u64,
        duration: Duration,
    },
    Custom {
        task_id: u64,
        job_fn: Box<dyn FnOnce() -> Result<TaskOutput, String> + Send + 'static>,
    },
}

/// Threadpool executing background operations.
pub struct WorkerThreadPool {
    sender: Sender<Job>,
    _threads: Vec<JoinHandle<()>>,
    running: Arc<AtomicBool>,
    next_task_id: AtomicU64,
    result_receiver: Receiver<TaskCompletion>,
}

impl WorkerThreadPool {
    /// Create a new thread pool with the specified number of worker threads.
    pub fn new(num_workers: usize) -> Self {
        let (job_tx, job_rx) = channel::<Job>();
        let (result_tx, result_rx) = channel::<TaskCompletion>();
        let job_rx = Arc::new(std::sync::Mutex::new(job_rx));
        let running = Arc::new(AtomicBool::new(true));

        let mut threads = Vec::with_capacity(num_workers);
        for worker_idx in 0..num_workers {
            let rx = Arc::clone(&job_rx);
            let tx = result_tx.clone();
            let is_running = Arc::clone(&running);

            let handle = thread::Builder::new()
                .name(format!("zenith-worker-{}", worker_idx))
                .spawn(move || {
                    while is_running.load(Ordering::Acquire) {
                        let job = {
                            let lock = rx.lock().unwrap();
                            lock.recv()
                        };

                        let job = match job {
                            Ok(j) => j,
                            Err(_) => break, // Channel disconnected
                        };

                        match job {
                            Job::SpawnProcess { task_id, command, args } => {
                                let res = match std::process::Command::new(&command)
                                    .args(&args)
                                    .output()
                                {
                                    Ok(out) => Ok(TaskOutput::Process {
                                        stdout: String::from_utf8_lossy(&out.stdout).to_string(),
                                        stderr: String::from_utf8_lossy(&out.stderr).to_string(),
                                        exit_code: out.status.code().unwrap_or(-1),
                                    }),
                                    Err(e) => Err(format!("Failed to execute '{}': {}", command, e)),
                                };
                                let _ = tx.send(TaskCompletion { task_id, result: res });
                            }
                            Job::Delay { task_id, duration } => {
                                thread::sleep(duration);
                                let _ = tx.send(TaskCompletion {
                                    task_id,
                                    result: Ok(TaskOutput::Empty),
                                });
                            }
                            Job::Custom { task_id, job_fn } => {
                                let res = job_fn();
                                let _ = tx.send(TaskCompletion { task_id, result: res });
                            }
                        }
                    }
                })
                .expect("Failed to spawn background worker thread");

            threads.push(handle);
        }

        Self {
            sender: job_tx,
            _threads: threads,
            running,
            next_task_id: AtomicU64::new(1),
            result_receiver: result_rx,
        }
    }

    /// Spawns an external command in the background threadpool.
    pub fn spawn_process(&self, command: String, args: Vec<String>) -> u64 {
        let task_id = self.next_task_id.fetch_add(1, Ordering::Relaxed);
        let _ = self.sender.send(Job::SpawnProcess {
            task_id,
            command,
            args,
        });
        task_id
    }

    /// Schedules a timer delay in background.
    pub fn delay(&self, duration: Duration) -> u64 {
        let task_id = self.next_task_id.fetch_add(1, Ordering::Relaxed);
        let _ = self.sender.send(Job::Delay { task_id, duration });
        task_id
    }

    /// Submits a custom closure to run on the threadpool.
    pub fn submit<F>(&self, f: F) -> u64
    where
        F: FnOnce() -> Result<TaskOutput, String> + Send + 'static,
    {
        let task_id = self.next_task_id.fetch_add(1, Ordering::Relaxed);
        let _ = self.sender.send(Job::Custom {
            task_id,
            job_fn: Box::new(f),
        });
        task_id
    }

    /// Non-blocking drain of all completed background tasks.
    pub fn try_recv_completions(&self) -> Vec<TaskCompletion> {
        let mut completions = Vec::new();
        while let Ok(comp) = self.result_receiver.try_recv() {
            completions.push(comp);
        }
        completions
    }
}

impl Drop for WorkerThreadPool {
    fn drop(&mut self) {
        self.running.store(false, Ordering::Release);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_worker_thread_pool_delay() {
        let pool = WorkerThreadPool::new(2);
        let id = pool.delay(Duration::from_millis(10));
        assert!(id >= 1);

        let start = std::time::Instant::now();
        let mut results = Vec::new();
        while start.elapsed() < Duration::from_millis(1000) {
            results = pool.try_recv_completions();
            if !results.is_empty() {
                break;
            }
            thread::sleep(Duration::from_millis(10));
        }

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].task_id, id);
        assert!(matches!(results[0].result, Ok(TaskOutput::Empty)));
    }

    #[test]
    fn test_worker_thread_pool_spawn_process() {
        let pool = WorkerThreadPool::new(2);
        let id = pool.spawn_process("echo".to_string(), vec!["zenith_async_ok".to_string()]);
        assert!(id >= 1);

        let start = std::time::Instant::now();
        let mut results = Vec::new();
        while start.elapsed() < Duration::from_millis(1500) {
            results = pool.try_recv_completions();
            if !results.is_empty() {
                break;
            }
            thread::sleep(Duration::from_millis(10));
        }

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].task_id, id);
        if let Ok(TaskOutput::Process { ref stdout, exit_code, .. }) = results[0].result {
            assert_eq!(exit_code, 0);
            assert!(stdout.contains("zenith_async_ok"));
        } else {
            panic!("Unexpected process result: {:?}", results[0].result);
        }
    }
}
