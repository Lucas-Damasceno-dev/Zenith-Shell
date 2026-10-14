//! Zenith-Shell CLI and IPC control crate.

pub mod ipc;

pub use ipc::{
    read_self_memory, read_vmrss_kb, resolve_socket_path, send_socket_command,
    send_socket_command_to, start_ipc_server, IpcServerHandle, ShellCommand,
};
