//! Integration Tests for Zenith-Shell IPC Socket (`zenith-cli reload`, inspect, toggle, etc.)

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use tempfile::tempdir;
use zenith_cli::{send_socket_command_to, start_ipc_server, ShellCommand};

#[test]
fn test_ipc_socket_handshake_and_reload() {
    let tmp = tempdir().expect("Failed to create temporary directory");
    let sock_path = tmp.path().join("zenith_test.sock");

    let reload_count = Arc::new(AtomicUsize::new(0));
    let reload_count_clone = reload_count.clone();

    let mut server = start_ipc_server(sock_path.clone(), move |cmd| match cmd {
        ShellCommand::Reload => {
            reload_count_clone.fetch_add(1, Ordering::SeqCst);
            None
        }
        _ => None,
    })
    .expect("Failed to bind test IPC server");

    // Wait a brief instant for listener to initialize
    thread::sleep(Duration::from_millis(50));

    // Send reload command
    let resp = send_socket_command_to(&sock_path, "reload")
        .expect("Failed to send reload command to IPC socket");

    assert_eq!(resp, "OK: reload scheduled");
    assert_eq!(
        reload_count.load(Ordering::SeqCst),
        1,
        "Reload command should be dispatched to handler"
    );

    // Stop server and ensure clean exit
    server.stop();
    assert!(!sock_path.exists(), "Socket file should be cleaned up upon server stop");
}

#[test]
fn test_ipc_socket_full_command_suite() {
    let tmp = tempdir().expect("Failed to create temporary directory");
    let sock_path = tmp.path().join("zenith_suite.sock");

    let last_command = Arc::new(std::sync::Mutex::new(String::new()));
    let last_cmd_clone = last_command.clone();

    let mut server = start_ipc_server(sock_path.clone(), move |cmd| match cmd {
        ShellCommand::Reload => {
            *last_cmd_clone.lock().unwrap() = "reload".to_string();
            None
        }
        ShellCommand::Toggle(id) => {
            *last_cmd_clone.lock().unwrap() = format!("toggle:{}", id);
            None
        }
        ShellCommand::Open(id) => {
            *last_cmd_clone.lock().unwrap() = format!("open:{}", id);
            None
        }
        ShellCommand::Close => {
            *last_cmd_clone.lock().unwrap() = "close".to_string();
            None
        }
        ShellCommand::Lock => {
            *last_cmd_clone.lock().unwrap() = "lock".to_string();
            None
        }
        ShellCommand::ToggleInspect => {
            *last_cmd_clone.lock().unwrap() = "inspect:toggle".to_string();
            None
        }
        ShellCommand::Eval(code, tx) => {
            *last_cmd_clone.lock().unwrap() = format!("eval:{}", code);
            let _ = tx.send("42\n".to_string());
            None
        }
        _ => None,
    })
    .expect("Failed to start IPC test server");

    thread::sleep(Duration::from_millis(50));

    // 1. Reload
    let res = send_socket_command_to(&sock_path, "reload").unwrap();
    assert_eq!(res, "OK: reload scheduled");
    assert_eq!(*last_command.lock().unwrap(), "reload");

    // 2. Toggle Launcher
    let res = send_socket_command_to(&sock_path, "toggle Launcher").unwrap();
    assert_eq!(res, "OK: toggle dispatched");
    assert_eq!(*last_command.lock().unwrap(), "toggle:Launcher");

    // 3. Open AudioPopup
    let res = send_socket_command_to(&sock_path, "open AudioPopup").unwrap();
    assert_eq!(res, "OK: open dispatched");
    assert_eq!(*last_command.lock().unwrap(), "open:AudioPopup");

    // 4. Close
    let res = send_socket_command_to(&sock_path, "close").unwrap();
    assert_eq!(res, "OK: close dispatched");
    assert_eq!(*last_command.lock().unwrap(), "close");

    // 5. Lock
    let res = send_socket_command_to(&sock_path, "lock").unwrap();
    assert_eq!(res, "OK: native lock screen activated");
    assert_eq!(*last_command.lock().unwrap(), "lock");

    // 6. Inspect (telemetry JSON)
    let res = send_socket_command_to(&sock_path, "inspect").unwrap();
    assert!(res.contains("\"status\":\"running\""));
    assert!(res.contains("\"vmrss_mb\":"));
    assert!(res.contains("\"heap_mb\":"));

    // 7. Inspect Toggle
    let res = send_socket_command_to(&sock_path, "inspect:toggle").unwrap();
    assert_eq!(res, "OK: inspect mode toggled");
    assert_eq!(*last_command.lock().unwrap(), "inspect:toggle");

    // 8. Eval
    let res = send_socket_command_to(&sock_path, "eval 40 + 2").unwrap();
    assert_eq!(res, "42");
    assert_eq!(*last_command.lock().unwrap(), "eval:40 + 2");

    // 9. Unknown command
    let res = send_socket_command_to(&sock_path, "nonexistent_cmd").unwrap();
    assert_eq!(res, "ERR: unknown command");

    server.stop();
}

#[test]
fn test_ipc_concurrency_stress() {
    let tmp = tempdir().expect("Failed to create temporary directory");
    let sock_path = tmp.path().join("zenith_stress.sock");

    let counter = Arc::new(AtomicUsize::new(0));
    let counter_clone = counter.clone();

    let mut server = start_ipc_server(sock_path.clone(), move |cmd| {
        if matches!(cmd, ShellCommand::Reload) {
            counter_clone.fetch_add(1, Ordering::SeqCst);
        }
        None
    })
    .expect("Failed to start IPC server for concurrency stress test");

    thread::sleep(Duration::from_millis(50));

    // Spawn 20 concurrent threads hammering the reload socket
    let thread_count = 20;
    let mut handles = Vec::new();

    for _ in 0..thread_count {
        let p = sock_path.clone();
        handles.push(thread::spawn(move || {
            let res = send_socket_command_to(&p, "reload");
            assert!(res.is_ok());
            assert_eq!(res.unwrap(), "OK: reload scheduled");
        }));
    }

    for h in handles {
        h.join().unwrap();
    }

    assert_eq!(
        counter.load(Ordering::SeqCst),
        thread_count,
        "All concurrent reload commands must be safely received and processed"
    );

    server.stop();
}

#[test]
fn test_ipc_all_overlay_popups_dispatch() {
    let tmp = tempdir().expect("Failed to create temporary directory");
    let sock_path = tmp.path().join("zenith_popups.sock");

    let received_commands = Arc::new(std::sync::Mutex::new(Vec::new()));
    let rec_clone = received_commands.clone();

    let mut server = start_ipc_server(sock_path.clone(), move |cmd| {
        match cmd {
            ShellCommand::Toggle(id) => {
                rec_clone.lock().unwrap().push(format!("toggle:{}", id));
                None
            }
            ShellCommand::Open(id) => {
                rec_clone.lock().unwrap().push(format!("open:{}", id));
                None
            }
            ShellCommand::Close => {
                rec_clone.lock().unwrap().push("close".to_string());
                None
            }
            _ => None,
        }
    })
    .expect("Failed to bind popup IPC server");

    thread::sleep(Duration::from_millis(50));

    let popups = [
        "Launcher",
        "Dock",
        "DynamicIsland",
        "DesktopCanvas",
        "AudioPopup",
        "BatteryPopup",
        "NetworkPopup",
        "BluetoothPopup",
        "PowerMenu",
        "NotificationCenter",
        "CalendarPopup",
    ];

    for popup in popups {
        // Test toggle
        let res = send_socket_command_to(&sock_path, &format!("toggle {}", popup)).unwrap();
        assert_eq!(res, "OK: toggle dispatched");

        // Test open
        let res = send_socket_command_to(&sock_path, &format!("open {}", popup)).unwrap();
        assert_eq!(res, "OK: open dispatched");
    }

    let res = send_socket_command_to(&sock_path, "close").unwrap();
    assert_eq!(res, "OK: close dispatched");

    let cmds = received_commands.lock().unwrap();
    assert_eq!(cmds.len(), popups.len() * 2 + 1);
    assert_eq!(cmds[0], "toggle:Launcher");
    assert_eq!(cmds[1], "open:Launcher");
    assert_eq!(*cmds.last().unwrap(), "close");

    server.stop();
}

#[test]
fn test_ipc_inspect_memory_telemetry() {
    let tmp = tempdir().expect("Failed to create temporary directory");
    let sock_path = tmp.path().join("zenith_inspect.sock");

    let mut server = start_ipc_server(sock_path.clone(), |_| None)
        .expect("Failed to bind inspect IPC server");

    thread::sleep(Duration::from_millis(50));

    let res = send_socket_command_to(&sock_path, "inspect").unwrap();
    let parsed: serde_json::Value = serde_json::from_str(&res).expect("Inspect response must be valid JSON");

    assert_eq!(parsed["status"], "running");
    let vmrss = parsed["vmrss_mb"].as_f64().expect("vmrss_mb must be f64");
    let heap = parsed["heap_mb"].as_f64().expect("heap_mb must be f64");

    println!("IPC inspect telemetry -> VmRSS: {:.2} MB, Heap: {:.2} MB", vmrss, heap);
    assert!(vmrss > 0.0, "VmRSS in telemetry must be positive");
    assert!(heap > 0.0, "Heap in telemetry must be positive");
    assert!(vmrss < 15.0, "Telemetry VmRSS ({:.2} MB) must be strictly below 15MB SLA limit!", vmrss);

    server.stop();
}

#[test]
fn test_sanitized_spawner_subsystem() {
    use zenith_runtime::spawner::{parse_command_line, spawn_detached};

    // 1. Clean command line parsing without shell
    let (prog, args) = parse_command_line("alacritty --title Terminal -e htop").unwrap();
    assert_eq!(prog, "alacritty");
    assert_eq!(args, vec!["--title", "Terminal", "-e", "htop"]);

    // 2. Shell metacharacters trigger shell fallback
    assert!(parse_command_line("cat /etc/os-release | grep ID").is_none());
    assert!(parse_command_line("echo $HOME").is_none());
    assert!(parse_command_line("sleep 1 &").is_none());
    assert!(parse_command_line("ls && echo ok").is_none());

    // 3. Detached execution test with a harmless utility
    let child = spawn_detached("true");
    assert!(child.is_ok(), "Detached spawn should succeed for standard binary");
}
