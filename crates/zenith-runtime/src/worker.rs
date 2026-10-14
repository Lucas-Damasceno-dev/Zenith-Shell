//! Background Worker ThreadPool and Asynchronous Task Engine for Zenith Luau.
//!
//! Provides non-blocking concurrency for heavy operations (process execution,
//! delayed timers, I/O tasks) communicating via MPSC channels with the main UI thread.
//! Supports execution timeouts and graceful cancellation across all worker tasks.

use std::collections::HashSet;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::{Arc, Mutex, RwLock};
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
        timeout: Option<Duration>,
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
    threads: Mutex<Vec<JoinHandle<()>>>,
    running: Arc<AtomicBool>,
    cancelled_tasks: Arc<RwLock<HashSet<u64>>>,
    next_task_id: AtomicU64,
    result_receiver: Mutex<Receiver<TaskCompletion>>,
}

impl WorkerThreadPool {
    /// Create a new thread pool with the specified number of worker threads.
    pub fn new(num_workers: usize) -> Self {
        let (job_tx, job_rx) = channel::<Job>();
        let (result_tx, result_rx) = channel::<TaskCompletion>();
        let job_rx = Arc::new(Mutex::new(job_rx));
        let running = Arc::new(AtomicBool::new(true));
        let cancelled_tasks = Arc::new(RwLock::new(HashSet::new()));

        let mut threads = Vec::with_capacity(num_workers);
        for worker_idx in 0..num_workers {
            let rx = Arc::clone(&job_rx);
            let tx = result_tx.clone();
            let is_running = Arc::clone(&running);
            let cancelled = Arc::clone(&cancelled_tasks);

            let handle = thread::Builder::new()
                .name(format!("zenith-worker-{}", worker_idx))
                .spawn(move || {
                    let is_task_cancelled = |id: u64| -> bool {
                        cancelled.read().map(|set| set.contains(&id)).unwrap_or(false)
                    };

                    while is_running.load(Ordering::Acquire) {
                        let job = {
                            let lock = match rx.lock() {
                                Ok(guard) => guard,
                                Err(poisoned) => poisoned.into_inner(),
                            };
                            match lock.recv_timeout(Duration::from_millis(100)) {
                                Ok(j) => j,
                                Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                                Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                            }
                        };

                        match job {
                            Job::SpawnProcess {
                                task_id,
                                command,
                                args,
                                timeout,
                            } => {
                                if is_task_cancelled(task_id) || !is_running.load(Ordering::Acquire) {
                                    let _ = tx.send(TaskCompletion {
                                        task_id,
                                        result: Err("Task cancelled".to_string()),
                                    });
                                    continue;
                                }

                                let mut child = match std::process::Command::new(&command)
                                    .args(&args)
                                    .stdin(std::process::Stdio::null())
                                    .stdout(std::process::Stdio::piped())
                                    .stderr(std::process::Stdio::piped())
                                    .spawn()
                                {
                                    Ok(c) => c,
                                    Err(e) => {
                                        let _ = tx.send(TaskCompletion {
                                            task_id,
                                            result: Err(format!("Failed to execute '{}': {}", command, e)),
                                        });
                                        continue;
                                    }
                                };

                                let stdout = child.stdout.take();
                                let stderr = child.stderr.take();

                                let stdout_reader = thread::spawn(move || {
                                    use std::io::Read;
                                    let mut buf = Vec::new();
                                    if let Some(mut stream) = stdout {
                                        let _ = stream.read_to_end(&mut buf);
                                    }
                                    buf
                                });

                                let stderr_reader = thread::spawn(move || {
                                    use std::io::Read;
                                    let mut buf = Vec::new();
                                    if let Some(mut stream) = stderr {
                                        let _ = stream.read_to_end(&mut buf);
                                    }
                                    buf
                                });

                                let start = std::time::Instant::now();
                                let mut exit_status = None;
                                let mut timed_out = false;
                                let mut was_cancelled = false;
                                let poll_step = Duration::from_millis(15);

                                loop {
                                    if !is_running.load(Ordering::Acquire) || is_task_cancelled(task_id) {
                                        was_cancelled = true;
                                        let _ = child.kill();
                                        let _ = child.wait();
                                        break;
                                    }

                                    match child.try_wait() {
                                        Ok(Some(status)) => {
                                            exit_status = Some(status);
                                            break;
                                        }
                                        Ok(None) => {
                                            if let Some(to) = timeout {
                                                if start.elapsed() >= to {
                                                    timed_out = true;
                                                    let _ = child.kill();
                                                    let _ = child.wait();
                                                    break;
                                                }
                                            }
                                            thread::sleep(poll_step);
                                        }
                                        Err(e) => {
                                            let _ = child.kill();
                                            let _ = child.wait();
                                            let _ = tx.send(TaskCompletion {
                                                task_id,
                                                result: Err(format!(
                                                    "Error waiting for command '{}': {}",
                                                    command, e
                                                )),
                                            });
                                            break;
                                        }
                                    }
                                }

                                let stdout_bytes = stdout_reader.join().unwrap_or_default();
                                let stderr_bytes = stderr_reader.join().unwrap_or_default();

                                if was_cancelled {
                                    let _ = tx.send(TaskCompletion {
                                        task_id,
                                        result: Err("Task cancelled".to_string()),
                                    });
                                } else if timed_out {
                                    let _ = tx.send(TaskCompletion {
                                        task_id,
                                        result: Err(format!(
                                            "Command '{}' timed out after {:?}",
                                            command,
                                            timeout.unwrap()
                                        )),
                                    });
                                } else if let Some(status) = exit_status {
                                    let res = TaskOutput::Process {
                                        stdout: String::from_utf8_lossy(&stdout_bytes).to_string(),
                                        stderr: String::from_utf8_lossy(&stderr_bytes).to_string(),
                                        exit_code: status.code().unwrap_or(-1),
                                    };
                                    let _ = tx.send(TaskCompletion {
                                        task_id,
                                        result: Ok(res),
                                    });
                                }
                            }
                            Job::Delay { task_id, duration } => {
                                let start = std::time::Instant::now();
                                let mut cancelled_flag = false;
                                while start.elapsed() < duration {
                                    if !is_running.load(Ordering::Acquire) || is_task_cancelled(task_id) {
                                        cancelled_flag = true;
                                        break;
                                    }
                                    let rem = duration.saturating_sub(start.elapsed());
                                    let step = rem.min(Duration::from_millis(15));
                                    thread::sleep(step);
                                }

                                if cancelled_flag {
                                    let _ = tx.send(TaskCompletion {
                                        task_id,
                                        result: Err("Task cancelled".to_string()),
                                    });
                                } else {
                                    let _ = tx.send(TaskCompletion {
                                        task_id,
                                        result: Ok(TaskOutput::Empty),
                                    });
                                }
                            }
                            Job::Custom { task_id, job_fn } => {
                                if !is_running.load(Ordering::Acquire) || is_task_cancelled(task_id) {
                                    let _ = tx.send(TaskCompletion {
                                        task_id,
                                        result: Err("Task cancelled".to_string()),
                                    });
                                } else {
                                    let res = job_fn();
                                    let _ = tx.send(TaskCompletion { task_id, result: res });
                                }
                            }
                        }
                    }
                })
                .expect("Failed to spawn background worker thread");

            threads.push(handle);
        }

        Self {
            sender: job_tx,
            threads: Mutex::new(threads),
            running,
            cancelled_tasks,
            next_task_id: AtomicU64::new(1),
            result_receiver: Mutex::new(result_rx),
        }
    }

    /// Spawns an external command in the background threadpool with no timeout limit.
    pub fn spawn_process(&self, command: String, args: Vec<String>) -> u64 {
        self.spawn_process_with_timeout(command, args, None)
    }

    /// Spawns an external command in the background threadpool with an optional timeout.
    pub fn spawn_process_with_timeout(
        &self,
        command: String,
        args: Vec<String>,
        timeout: Option<Duration>,
    ) -> u64 {
        let task_id = self.next_task_id.fetch_add(1, Ordering::Relaxed);
        let _ = self.sender.send(Job::SpawnProcess {
            task_id,
            command,
            args,
            timeout,
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

    /// Cancels a running or queued background task by ID.
    pub fn cancel_task(&self, task_id: u64) -> bool {
        if let Ok(mut set) = self.cancelled_tasks.write() {
            set.insert(task_id);
            true
        } else {
            false
        }
    }

    /// Checks if a task ID is marked as cancelled.
    pub fn is_cancelled(&self, task_id: u64) -> bool {
        self.cancelled_tasks
            .read()
            .map(|set| set.contains(&task_id))
            .unwrap_or(false)
    }

    /// Cancels all ongoing tasks and signals worker threads to stop.
    pub fn cancel_all(&self) {
        self.running.store(false, Ordering::Release);
    }

    /// Non-blocking drain of all completed background tasks.
    pub fn try_recv_completions(&self) -> Vec<TaskCompletion> {
        let mut completions = Vec::new();
        if let Ok(rx) = self.result_receiver.lock() {
            while let Ok(comp) = rx.try_recv() {
                if let Ok(mut set) = self.cancelled_tasks.write() {
                    set.remove(&comp.task_id);
                }
                completions.push(comp);
            }
        }
        completions
    }
}

impl Drop for WorkerThreadPool {
    fn drop(&mut self) {
        self.running.store(false, Ordering::Release);
        if let Ok(mut lock) = self.threads.lock() {
            for handle in lock.drain(..) {
                let _ = handle.join();
            }
        }
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

    #[test]
    fn test_worker_thread_pool_spawn_timeout() {
        let pool = WorkerThreadPool::new(2);
        let id = pool.spawn_process_with_timeout(
            "sleep".to_string(),
            vec!["5".to_string()],
            Some(Duration::from_millis(50)),
        );
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
        match &results[0].result {
            Err(e) => assert!(e.contains("timed out"), "Expected timed out, got: {}", e),
            Ok(val) => panic!("Expected timeout error, got Ok: {:?}", val),
        }
    }

    #[test]
    fn test_worker_thread_pool_cancel_delay() {
        let pool = WorkerThreadPool::new(2);
        let id = pool.delay(Duration::from_secs(5));
        assert!(id >= 1);

        assert!(pool.cancel_task(id));

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
        match &results[0].result {
            Err(e) => assert!(e.contains("cancelled"), "Expected cancelled, got: {}", e),
            Ok(val) => panic!("Expected cancellation error, got Ok: {:?}", val),
        }
    }

    #[test]
    fn test_worker_thread_pool_cancel_process() {
        let pool = WorkerThreadPool::new(2);
        let id = pool.spawn_process("sleep".to_string(), vec!["5".to_string()]);
        assert!(id >= 1);

        assert!(pool.cancel_task(id));

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
        match &results[0].result {
            Err(e) => assert!(e.contains("cancelled"), "Expected cancelled, got: {}", e),
            Ok(val) => panic!("Expected cancellation error, got Ok: {:?}", val),
        }
    }

    #[test]
    fn test_worker_thread_pool_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<WorkerThreadPool>();
    }
}
