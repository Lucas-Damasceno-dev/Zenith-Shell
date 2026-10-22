//! IPC Control Protocol & Socket Server/Client for Zenith-Shell.
//!
//! Provides sub-millisecond UNIX domain socket IPC communication for triggering
//! hot-reloads (`zenith-cli reload`), toggling overlays, evaluating Luau expressions,
//! and querying memory diagnostics (VmRSS & heap).

use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tracing::info;

/// High-level commands received over the Zenith UNIX domain socket.
#[derive(Debug, Clone)]
pub enum ShellCommand {
    Reload,
    Toggle(String),
    Open(String),
    Close,
    Lock,
    Inspect,
    ToggleInspect,
    Eval(String, std::sync::mpsc::Sender<String>),
    SettingsGet(String, std::sync::mpsc::Sender<String>),
    SettingsSet(String, String, std::sync::mpsc::Sender<String>),
    SettingsList(std::sync::mpsc::Sender<String>),
    SettingsSync(std::sync::mpsc::Sender<String>),
    SettingsReload(std::sync::mpsc::Sender<String>),
    SettingsResetDefaults(std::sync::mpsc::Sender<String>),
}

/// Resolves the UNIX domain socket path for Zenith IPC.
///
/// Precedence:
/// 1. `ZENITH_SOCKET_PATH` environment variable (ideal for isolated integration tests).
/// 2. `/run/user/<uid>/zenith-shell.sock` (standard POSIX runtime path).
/// 3. `$XDG_RUNTIME_DIR/zenith-shell.sock` (with legacy fallback).
/// 4. `~/.cache/zenith/run/zenith-shell.sock` (permission-restricted 0700 fallback).
pub fn resolve_socket_path() -> PathBuf {
    if let Ok(custom) = std::env::var("ZENITH_SOCKET_PATH") {
        if !custom.trim().is_empty() {
            return PathBuf::from(custom.trim());
        }
    }

    #[cfg(target_os = "linux")]
    {
        let uid = unsafe { libc::getuid() };
        let modern = PathBuf::from(format!("/run/user/{}/zenith-shell.sock", uid));
        let legacy = PathBuf::from(format!("/run/user/{}/zenith.sock", uid));
        if modern.exists() {
            return modern;
        }
        if legacy.exists() {
            return legacy;
        }
        if modern.parent().map(|p| p.exists()).unwrap_or(false) {
            return modern;
        }
    }

    if let Ok(dir) = std::env::var("XDG_RUNTIME_DIR") {
        let p = PathBuf::from(dir);
        let modern = p.join("zenith-shell.sock");
        let legacy = p.join("zenith.sock");
        if legacy.exists() && !modern.exists() {
            legacy
        } else {
            modern
        }
    } else {
        if let Ok(home) = std::env::var("HOME") {
            let safe_dir = PathBuf::from(home).join(".cache/zenith/run");
            let _ = fs::create_dir_all(&safe_dir);
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = fs::set_permissions(&safe_dir, fs::Permissions::from_mode(0o700));
            }
            safe_dir.join("zenith-shell.sock")
        } else {
            PathBuf::from("/tmp/zenith-shell.sock")
        }
    }
}


/// Reads current process memory metrics from Linux `/proc/self/status` and `/proc/self/statm`.
///
/// Returns `(vmrss_mb, heap_mb)`.
pub fn read_self_memory() -> (f64, f64) {
    let mut vmrss_mb = 0.0;
    if let Ok(status) = fs::read_to_string("/proc/self/status") {
        for line in status.lines() {
            if line.starts_with("VmRSS:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    if let Ok(kb) = parts[1].parse::<f64>() {
                        vmrss_mb = kb / 1024.0;
                    }
                }
            }
        }
    }

    let mut heap_mb = 0.0;
    if let Ok(statm) = fs::read_to_string("/proc/self/statm") {
        let parts: Vec<&str> = statm.split_whitespace().collect();
        if parts.len() >= 6 {
            if let Ok(pages) = parts[5].parse::<f64>() {
                heap_mb = (pages * 4096.0) / (1024.0 * 1024.0);
            }
        }
    }

    (vmrss_mb, heap_mb)
}

/// Reads current VmRSS in kilobytes directly from `/proc/self/status`.
pub fn read_vmrss_kb() -> Option<u64> {
    let status = fs::read_to_string("/proc/self/status").ok()?;
    for line in status.lines() {
        if line.starts_with("VmRSS:") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                return parts[1].parse::<u64>().ok();
            }
        }
    }
    None
}

#[cfg(target_os = "linux")]
fn verify_peer_credentials(stream: &UnixStream) -> bool {
    use std::os::unix::io::AsRawFd;
    let fd = stream.as_raw_fd();
    let mut ucred = libc::ucred {
        pid: 0,
        uid: 0,
        gid: 0,
    };
    let mut len = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
    let ret = unsafe {
        libc::getsockopt(
            fd,
            libc::SOL_SOCKET,
            libc::SO_PEERCRED,
            &mut ucred as *mut _ as *mut libc::c_void,
            &mut len,
        )
    };
    if ret == 0 {
        let current_uid = unsafe { libc::getuid() };
        ucred.uid == current_uid
    } else {
        false
    }
}

#[cfg(not(target_os = "linux"))]
fn verify_peer_credentials(_stream: &UnixStream) -> bool {
    true
}

/// Sends a single command to the Zenith IPC socket at a custom path and returns the response string.
pub fn send_socket_command_to(
    sock_path: &Path,
    cmd: &str,
) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    if !sock_path.exists() {
        return Err(format!(
            "Zenith daemon is not running (socket not found at {}).",
            sock_path.display()
        )
        .into());
    }

    let mut stream = UnixStream::connect(sock_path)?;
    stream.set_read_timeout(Some(Duration::from_millis(1000)))?;
    stream.set_write_timeout(Some(Duration::from_millis(1000)))?;

    stream.write_all(format!("{}\n", cmd.trim()).as_bytes())?;
    stream.flush()?;

    let mut reader = BufReader::new(stream);
    let mut response = String::new();
    reader.read_line(&mut response)?;

    Ok(response.trim().to_string())
}

/// Sends a command to the default resolved Zenith IPC socket.
pub fn send_socket_command(cmd: &str) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    let sock_path = resolve_socket_path();
    send_socket_command_to(&sock_path, cmd)
}

/// Handle for a running background IPC server.
pub struct IpcServerHandle {
    sock_path: PathBuf,
    running: Arc<AtomicBool>,
    thread: Option<std::thread::JoinHandle<()>>,
}

impl IpcServerHandle {
    /// Returns the socket path this server is bound to.
    pub fn socket_path(&self) -> &Path {
        &self.sock_path
    }

    /// Stops the IPC server thread and cleans up the socket file.
    pub fn stop(&mut self) {
        if self.running.swap(false, Ordering::SeqCst) {
            // Wake up blocking accept() by making a dummy connection
            let _ = UnixStream::connect(&self.sock_path);
            if let Some(handle) = self.thread.take() {
                let _ = handle.join();
            }
            if self.sock_path.exists() {
                let _ = fs::remove_file(&self.sock_path);
            }
        }
    }
}

impl Drop for IpcServerHandle {
    fn drop(&mut self) {
        self.stop();
    }
}

/// Spawns an IPC server on the specified socket path with a custom command dispatcher.
pub fn start_ipc_server<F>(
    sock_path: PathBuf,
    cmd_handler: F,
) -> Result<IpcServerHandle, Box<dyn std::error::Error + Send + Sync>>
where
    F: Fn(ShellCommand) -> Option<String> + Send + Sync + 'static,
{
    if sock_path.exists() {
        let _ = fs::remove_file(&sock_path);
    }

    let listener = UnixListener::bind(&sock_path)?;

    // Security Hardening: Enforce strict 0600 POSIX permissions immediately after bind
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&sock_path, fs::Permissions::from_mode(0o600));
    }

    info!("IPC control socket listening at: {}", sock_path.display());

    let running = Arc::new(AtomicBool::new(true));
    let running_thread = running.clone();
    let thread_sock_path = sock_path.clone();
    let handler = Arc::new(cmd_handler);

    let thread = std::thread::spawn(move || {
        while running_thread.load(Ordering::SeqCst) {
            let (mut stream, _) = match listener.accept() {
                Ok(conn) => conn,
                Err(_) => {
                    if !running_thread.load(Ordering::SeqCst) {
                        break;
                    }
                    continue;
                }
            };

            if !running_thread.load(Ordering::SeqCst) {
                break;
            }

            // Security Hardening: Strict I/O timeouts (1.0s) to prevent Slowloris / thread exhaustion
            let _ = stream.set_read_timeout(Some(Duration::from_millis(1000)));
            let _ = stream.set_write_timeout(Some(Duration::from_millis(1000)));

            // Security Hardening: Enforce kernel-level SO_PEERCRED check (uid == getuid())
            if !verify_peer_credentials(&stream) {
                tracing::warn!("Unauthorized IPC connection attempt rejected by SO_PEERCRED check");
                let _ = stream.write_all(b"ERR: unauthorized peer credentials\n");
                continue;
            }

            let handler_ref = handler.clone();
            let inspect_path = thread_sock_path.clone();

            // Security Hardening: Strict 64KB payload buffer limit to prevent memory exhaustion DoS
            use std::io::Read;
            let mut limited_reader = BufReader::new(&stream).take(65536);
            let mut line = String::new();
            if limited_reader.read_line(&mut line).is_err() {
                continue;
            }

            if line.len() >= 65536 && !line.ends_with('\n') {
                tracing::warn!("IPC payload exceeded 64KB limit, rejecting stream");
                let _ = stream.write_all(b"ERR: payload exceeds 64KB limit\n");
                continue;
            }

            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }

            if trimmed == "reload" {
                let _ = handler_ref(ShellCommand::Reload);
                let _ = stream.write_all(b"OK: reload scheduled\n");
            } else if let Some(stripped) = trimmed.strip_prefix("toggle ") {
                let id = stripped.trim().to_string();
                let _ = handler_ref(ShellCommand::Toggle(id));
                let _ = stream.write_all(b"OK: toggle dispatched\n");
            } else if let Some(stripped) = trimmed.strip_prefix("open ") {
                let id = stripped.trim().to_string();
                let _ = handler_ref(ShellCommand::Open(id));
                let _ = stream.write_all(b"OK: open dispatched\n");
            } else if trimmed == "close" {
                let _ = handler_ref(ShellCommand::Close);
                let _ = stream.write_all(b"OK: close dispatched\n");
            } else if trimmed == "lock" {
                let _ = handler_ref(ShellCommand::Lock);
                let _ = stream.write_all(b"OK: native lock screen activated\n");
            } else if trimmed == "inspect" {
                let (vmrss_mb, heap_mb) = read_self_memory();
                let resp = format!(
                    "{{\"status\":\"running\",\"vmrss_mb\":{:.2},\"heap_mb\":{:.2},\"socket\":\"{}\"}}\n",
                    vmrss_mb, heap_mb, inspect_path.display()
                );
                let _ = stream.write_all(resp.as_bytes());
            } else if trimmed == "inspect:toggle" || trimmed == "inspect-toggle" {
                let _ = handler_ref(ShellCommand::ToggleInspect);
                let _ = stream.write_all(b"OK: inspect mode toggled\n");
            } else if let Some(stripped) = trimmed.strip_prefix("eval ") {
                let (tx, rx) = std::sync::mpsc::channel();
                let _ = handler_ref(ShellCommand::Eval(stripped.to_string(), tx));
                match rx.recv_timeout(Duration::from_secs(5)) {
                    Ok(resp) => {
                        let _ = stream.write_all(resp.as_bytes());
                    }
                    Err(_) => {
                        let _ = stream.write_all(b"ERR: eval timeout\n");
                    }
                }
            } else if let Some(stripped) = trimmed.strip_prefix("settings:get ") {
                let key = stripped.trim().to_string();
                let (tx, rx) = std::sync::mpsc::channel();
                let _ = handler_ref(ShellCommand::SettingsGet(key, tx));
                match rx.recv_timeout(Duration::from_secs(5)) {
                    Ok(resp) => {
                        let _ = stream.write_all(resp.as_bytes());
                    }
                    Err(_) => {
                        let _ = stream.write_all(b"ERR: settings get timeout\n");
                    }
                }
            } else if let Some(stripped) = trimmed.strip_prefix("settings:set ") {
                let parts: Vec<&str> = stripped.trim().splitn(2, ' ').collect();
                if parts.len() == 2 {
                    let key = parts[0].to_string();
                    let val = parts[1].to_string();
                    let (tx, rx) = std::sync::mpsc::channel();
                    let _ = handler_ref(ShellCommand::SettingsSet(key, val, tx));
                    match rx.recv_timeout(Duration::from_secs(5)) {
                        Ok(resp) => {
                            let _ = stream.write_all(resp.as_bytes());
                        }
                        Err(_) => {
                            let _ = stream.write_all(b"ERR: settings set timeout\n");
                        }
                    }
                } else {
                    let _ = stream.write_all(b"ERR: invalid settings:set format (expected: settings:set <key> <val>)\n");
                }
            } else if trimmed == "settings:list" || trimmed == "settings:all" {
                let (tx, rx) = std::sync::mpsc::channel();
                let _ = handler_ref(ShellCommand::SettingsList(tx));
                match rx.recv_timeout(Duration::from_secs(5)) {
                    Ok(resp) => {
                        let _ = stream.write_all(resp.as_bytes());
                    }
                    Err(_) => {
                        let _ = stream.write_all(b"ERR: settings list timeout\n");
                    }
                }
            } else if trimmed == "settings:sync" {
                let (tx, rx) = std::sync::mpsc::channel();
                let _ = handler_ref(ShellCommand::SettingsSync(tx));
                match rx.recv_timeout(Duration::from_secs(5)) {
                    Ok(resp) => {
                        let _ = stream.write_all(resp.as_bytes());
                    }
                    Err(_) => {
                        let _ = stream.write_all(b"ERR: settings sync timeout\n");
                    }
                }
            } else if trimmed == "settings:reload" {
                let (tx, rx) = std::sync::mpsc::channel();
                let _ = handler_ref(ShellCommand::SettingsReload(tx));
                match rx.recv_timeout(Duration::from_secs(5)) {
                    Ok(resp) => {
                        let _ = stream.write_all(resp.as_bytes());
                    }
                    Err(_) => {
                        let _ = stream.write_all(b"ERR: settings reload timeout\n");
                    }
                }
            } else if trimmed == "settings:reset_defaults" || trimmed == "settings:reset-defaults" {
                let (tx, rx) = std::sync::mpsc::channel();
                let _ = handler_ref(ShellCommand::SettingsResetDefaults(tx));
                match rx.recv_timeout(Duration::from_secs(5)) {
                    Ok(resp) => {
                        let _ = stream.write_all(resp.as_bytes());
                    }
                    Err(_) => {
                        let _ = stream.write_all(b"ERR: settings reset_defaults timeout\n");
                    }
                }
            } else {
                let _ = stream.write_all(b"ERR: unknown command\n");
            }
        }
    });

    Ok(IpcServerHandle {
        sock_path,
        running,
        thread: Some(thread),
    })
}
