//! Background Worker ThreadPool and Asynchronous Task Engine for Zenith Luau.
//!
//! Provides non-blocking concurrency for heavy operations (process execution,
//! delayed timers, I/O tasks) communicating via MPSC channels with the main UI thread.
//! Supports execution timeouts and graceful cancellation across all worker tasks.

use std::collections::HashSet;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::{Arc, Condvar, Mutex, RwLock};
use std::thread::{self, JoinHandle};
use std::time::Duration;
use std::io::Read;
#[cfg(unix)]
use std::os::unix::io::AsRawFd;

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
    Custom {
        task_id: u64,
        job_fn: Box<dyn FnOnce() -> Result<TaskOutput, String> + Send + 'static>,
    },
    Shutdown,
}

/// Threadpool executing background operations.
pub struct WorkerThreadPool {
    sender: Sender<Job>,
    result_sender: Sender<TaskCompletion>,
    threads: Mutex<Vec<JoinHandle<()>>>,
    running: Arc<AtomicBool>,
    cancelled_tasks: Arc<(Mutex<HashSet<u64>>, Condvar)>,
    next_task_id: AtomicU64,
    result_receiver: Mutex<Receiver<TaskCompletion>>,
    completion_notifier: Arc<RwLock<Option<Arc<dyn Fn() + Send + Sync>>>>,
}

impl WorkerThreadPool {
    /// Create a new thread pool with the specified number of worker threads.
    pub fn new(num_workers: usize) -> Self {
        let (job_tx, job_rx) = channel::<Job>();
        let (result_tx, result_rx) = channel::<TaskCompletion>();
        let job_rx = Arc::new(Mutex::new(job_rx));
        let running = Arc::new(AtomicBool::new(true));
        let cancelled_tasks = Arc::new((Mutex::new(HashSet::new()), Condvar::new()));
        let completion_notifier: Arc<RwLock<Option<Arc<dyn Fn() + Send + Sync>>>> =
            Arc::new(RwLock::new(None));

        let mut threads = Vec::with_capacity(num_workers);
        for worker_idx in 0..num_workers {
            let rx = Arc::clone(&job_rx);
            let tx = result_tx.clone();
            let is_running = Arc::clone(&running);
            let cancelled = Arc::clone(&cancelled_tasks);
            let notifier = Arc::clone(&completion_notifier);

            let send_comp = move |comp: TaskCompletion| {
                let _ = tx.send(comp);
                if let Ok(guard) = notifier.read() {
                    if let Some(ref cb) = *guard {
                        cb();
                    }
                }
            };

            let handle = thread::Builder::new()
                .name(format!("zenith-worker-{}", worker_idx))
                .spawn(move || {
                    let is_task_cancelled = |id: u64| -> bool {
                        cancelled.0.lock().map(|set| set.contains(&id)).unwrap_or(false)
                    };

                    while is_running.load(Ordering::Acquire) {
                        let job = {
                            let lock = match rx.lock() {
                                Ok(guard) => guard,
                                Err(poisoned) => poisoned.into_inner(),
                            };
                            match lock.recv() {
                                Ok(j) => j,
                                Err(_) => break,
                            }
                        };

                        if matches!(job, Job::Shutdown) || !is_running.load(Ordering::Acquire) {
                            break;
                        }

                        match job {
                            Job::SpawnProcess {
                                task_id,
                                command,
                                args,
                                timeout,
                            } => {
                                if is_task_cancelled(task_id) || !is_running.load(Ordering::Acquire) {
                                    send_comp(TaskCompletion {
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
                                        send_comp(TaskCompletion {
                                            task_id,
                                            result: Err(format!("Failed to execute '{}': {}", command, e)),
                                        });
                                        continue;
                                    }
                                };

                                let mut stdout_stream = child.stdout.take();
                                let mut stderr_stream = child.stderr.take();

                                #[cfg(unix)]
                                let stdout_fd = stdout_stream.as_ref().map(|s| s.as_raw_fd()).unwrap_or(-1);
                                #[cfg(unix)]
                                let stderr_fd = stderr_stream.as_ref().map(|s| s.as_raw_fd()).unwrap_or(-1);

                                #[cfg(unix)]
                                unsafe {
                                    if stdout_fd >= 0 {
                                        let fl = libc::fcntl(stdout_fd, libc::F_GETFL);
                                        libc::fcntl(stdout_fd, libc::F_SETFL, fl | libc::O_NONBLOCK);
                                    }
                                    if stderr_fd >= 0 {
                                        let fl = libc::fcntl(stderr_fd, libc::F_GETFL);
                                        libc::fcntl(stderr_fd, libc::F_SETFL, fl | libc::O_NONBLOCK);
                                    }
                                }

                                let start = std::time::Instant::now();
                                let mut exit_status = None;
                                let mut timed_out = false;
                                let mut was_cancelled = false;
                                let mut stdout_bytes = Vec::new();
                                let mut stderr_bytes = Vec::new();
                                let mut buf = [0u8; 8192];
                                #[allow(unused_mut)]
                                let mut stdout_closed = false;
                                #[allow(unused_mut)]
                                let mut stderr_closed = false;

                                loop {
                                    if !is_running.load(Ordering::Acquire) || is_task_cancelled(task_id) {
                                        was_cancelled = true;
                                        let _ = child.kill();
                                        let _ = child.wait();
                                        break;
                                    }

                                    if let Some(to) = timeout {
                                        if start.elapsed() >= to {
                                            timed_out = true;
                                            let _ = child.kill();
                                            let _ = child.wait();
                                            break;
                                        }
                                    }

                                    // Drain available stdout in non-blocking chunks
                                    if !stdout_closed {
                                        if let Some(ref mut stream) = stdout_stream {
                                            loop {
                                                match stream.read(&mut buf) {
                                                    Ok(0) => {
                                                        stdout_closed = true;
                                                        break;
                                                    }
                                                    Ok(n) => stdout_bytes.extend_from_slice(&buf[..n]),
                                                    Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => break,
                                                    Err(_) => {
                                                        stdout_closed = true;
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Drain available stderr in non-blocking chunks
                                    if !stderr_closed {
                                        if let Some(ref mut stream) = stderr_stream {
                                            loop {
                                                match stream.read(&mut buf) {
                                                    Ok(0) => {
                                                        stderr_closed = true;
                                                        break;
                                                    }
                                                    Ok(n) => stderr_bytes.extend_from_slice(&buf[..n]),
                                                    Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => break,
                                                    Err(_) => {
                                                        stderr_closed = true;
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    match child.try_wait() {
                                        Ok(Some(status)) => {
                                            exit_status = Some(status);
                                            // Final drain
                                            if let Some(ref mut stream) = stdout_stream {
                                                let mut rest = Vec::new();
                                                let _ = stream.read_to_end(&mut rest);
                                                stdout_bytes.extend(rest);
                                            }
                                            if let Some(ref mut stream) = stderr_stream {
                                                let mut rest = Vec::new();
                                                let _ = stream.read_to_end(&mut rest);
                                                stderr_bytes.extend(rest);
                                            }
                                            break;
                                        }
                                        Ok(None) => {
                                            #[cfg(unix)]
                                            {
                                                let mut pollfds = [
                                                    libc::pollfd {
                                                        fd: if stdout_closed { -1 } else { stdout_fd },
                                                        events: libc::POLLIN | libc::POLLHUP,
                                                        revents: 0,
                                                    },
                                                    libc::pollfd {
                                                        fd: if stderr_closed { -1 } else { stderr_fd },
                                                        events: libc::POLLIN | libc::POLLHUP,
                                                        revents: 0,
                                                    },
                                                ];
                                                unsafe {
                                                    libc::poll(pollfds.as_mut_ptr(), 2, 15);
                                                }
                                            }
                                            #[cfg(not(unix))]
                                            {
                                                thread::sleep(Duration::from_millis(15));
                                            }
                                        }
                                        Err(e) => {
                                            let _ = child.kill();
                                            let _ = child.wait();
                                            send_comp(TaskCompletion {
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

                                if was_cancelled {
                                    send_comp(TaskCompletion {
                                        task_id,
                                        result: Err("Task cancelled".to_string()),
                                    });
                                } else if timed_out {
                                    send_comp(TaskCompletion {
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
                                    send_comp(TaskCompletion {
                                        task_id,
                                        result: Ok(res),
                                    });
                                }
                            }
                            Job::Custom { task_id, job_fn } => {
                                if !is_running.load(Ordering::Acquire) || is_task_cancelled(task_id) {
                                    send_comp(TaskCompletion {
                                        task_id,
                                        result: Err("Task cancelled".to_string()),
                                    });
                                } else {
                                    let res = job_fn();
                                    send_comp(TaskCompletion { task_id, result: res });
                                }
                            }
                            Job::Shutdown => break,
                        }
                    }
                })
                .expect("Failed to spawn background worker thread");

            threads.push(handle);
        }

        Self {
            sender: job_tx,
            result_sender: result_tx,
            threads: Mutex::new(threads),
            running,
            cancelled_tasks,
            next_task_id: AtomicU64::new(1),
            result_receiver: Mutex::new(result_rx),
            completion_notifier,
        }
    }

    /// Sets an external completion callback (e.g. Calloop Ping) to wake up the event loop when a task finishes.
    pub fn set_completion_notifier(&self, notifier: Arc<dyn Fn() + Send + Sync>) {
        if let Ok(mut lock) = self.completion_notifier.write() {
            *lock = Some(notifier);
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

    /// Schedules a timer delay in background on a non-blocking timer thread.
    pub fn delay(&self, duration: Duration) -> u64 {
        let task_id = self.next_task_id.fetch_add(1, Ordering::Relaxed);
        let sender = self.result_sender.clone();
        let notifier = self.completion_notifier.clone();
        let running = self.running.clone();
        let cancelled = self.cancelled_tasks.clone();

        std::thread::Builder::new()
            .name(format!("zenith-timer-{}", task_id))
            .spawn(move || {
                let start = std::time::Instant::now();
                let mut was_cancelled = false;
                let (lock, cvar) = &*cancelled;
                if let Ok(mut guard) = lock.lock() {
                    while start.elapsed() < duration {
                        if !running.load(Ordering::Acquire) || guard.contains(&task_id) {
                            was_cancelled = true;
                            break;
                        }
                        let rem = duration.saturating_sub(start.elapsed());
                        let (new_guard, timeout_res) = match cvar.wait_timeout(guard, rem) {
                            Ok(res) => res,
                            Err(poisoned) => poisoned.into_inner(),
                        };
                        guard = new_guard;
                        if timeout_res.timed_out() {
                            break;
                        }
                    }
                    if !was_cancelled && (!running.load(Ordering::Acquire) || guard.contains(&task_id)) {
                        was_cancelled = true;
                    }
                }
                let res = if was_cancelled {
                    Err("Task cancelled".to_string())
                } else {
                    Ok(TaskOutput::Empty)
                };
                let _ = sender.send(TaskCompletion { task_id, result: res });
                if let Ok(guard) = notifier.read() {
                    if let Some(ref cb) = *guard {
                        cb();
                    }
                }
            })
            .ok();

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
        let (lock, cvar) = &*self.cancelled_tasks;
        if let Ok(mut set) = lock.lock() {
            set.insert(task_id);
            cvar.notify_all();
            true
        } else {
            false
        }
    }

    /// Checks if a task ID is marked as cancelled.
    pub fn is_cancelled(&self, task_id: u64) -> bool {
        let (lock, _) = &*self.cancelled_tasks;
        lock.lock()
            .map(|set| set.contains(&task_id))
            .unwrap_or(false)
    }

    /// Cancels all ongoing tasks and signals worker threads to stop.
    pub fn cancel_all(&self) {
        self.running.store(false, Ordering::Release);
        self.cancelled_tasks.1.notify_all();
        if let Ok(threads) = self.threads.lock() {
            for _ in 0..threads.len() {
                let _ = self.sender.send(Job::Shutdown);
            }
        }
    }

    /// Non-blocking drain of all completed background tasks.
    pub fn try_recv_completions(&self) -> Vec<TaskCompletion> {
        let mut completions = Vec::new();
        if let Ok(rx) = self.result_receiver.lock() {
            while let Ok(comp) = rx.try_recv() {
                if let Ok(mut set) = self.cancelled_tasks.0.lock() {
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
        if let Ok(threads) = self.threads.lock() {
            for _ in 0..threads.len() {
                let _ = self.sender.send(Job::Shutdown);
            }
        }
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

    #[test]
    fn test_worker_thread_pool_large_output_no_pipe_deadlock() {
        let pool = WorkerThreadPool::new(2);
        let id = pool.spawn_process_with_timeout(
            "python3".to_string(),
            vec!["-c".to_string(), "import sys; sys.stdout.write('X' * 131072); sys.stderr.write('Y' * 131072)".to_string()],
            Some(Duration::from_secs(5)),
        );
        let start = std::time::Instant::now();
        let mut results = Vec::new();
        while start.elapsed() < Duration::from_secs(4) {
            results = pool.try_recv_completions();
            if !results.is_empty() {
                break;
            }
            thread::sleep(Duration::from_millis(10));
        }

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].task_id, id);
        if let Ok(TaskOutput::Process { stdout, stderr, exit_code }) = &results[0].result {
            assert_eq!(*exit_code, 0);
            assert_eq!(stdout.len(), 131072);
            assert_eq!(stderr.len(), 131072);
        } else {
            panic!("Expected successful process completion, got: {:?}", results[0].result);
        }
    }
}
