//! Sanitized process spawner and argument parsing for Zenith runtime.
//!
//! Provides decoupled external command execution without intermediate shell forks
//! when executing known binaries, configuring null stdio streams and detached
//! Unix process groups.

use std::process::{Command, Stdio};

/// Evaluates if a command line string can be executed directly without an intermediate shell.
///
/// Returns `Some((program, args))` if parsing succeeds and no shell metacharacters are present.
/// Returns `None` if shell operators or metacharacters (`|`, `&`, `;`, `<`, `>`, `$`, etc.)
/// are detected, requiring invocation via `sh -c`.
pub fn parse_command_line(cmd: &str) -> Option<(String, Vec<String>)> {
    let trimmed = cmd.trim();
    if trimmed.is_empty() {
        return None;
    }

    // Shell metacharacters requiring intermediate shell features
    const SHELL_METACHARS: &[char] = &['|', '&', ';', '<', '>', '$', '`', '*', '?', '\n', '\r'];
    if trimmed.contains(SHELL_METACHARS) {
        return None;
    }

    let mut tokens = Vec::new();
    let mut current = String::new();
    let mut in_single_quote = false;
    let mut in_double_quote = false;
    let mut escaped = false;

    for ch in trimmed.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
            continue;
        }

        match ch {
            '\\' if !in_single_quote => {
                escaped = true;
            }
            '\'' if !in_double_quote => {
                in_single_quote = !in_single_quote;
            }
            '"' if !in_single_quote => {
                in_double_quote = !in_double_quote;
            }
            c if c.is_whitespace() && !in_single_quote && !in_double_quote => {
                if !current.is_empty() {
                    tokens.push(current);
                    current = String::new();
                }
            }
            _ => {
                current.push(ch);
            }
        }
    }

    // Unbalanced quotes or dangling escapes fallback to shell
    if in_single_quote || in_double_quote || escaped {
        return None;
    }

    if !current.is_empty() {
        tokens.push(current);
    }

    if tokens.is_empty() {
        return None;
    }

    let program = tokens.remove(0);
    Some((program, tokens))
}

/// Constructs a detached Command configured with null stdio and a decoupled process group.
pub fn build_detached_command(cmd: &str) -> Command {
    let mut command = if let Some((program, args)) = parse_command_line(cmd) {
        let mut c = Command::new(program);
        c.args(args);
        c
    } else {
        let mut c = Command::new("sh");
        c.arg("-c").arg(cmd);
        c
    };

    command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        command.process_group(0);
    }

    command
}

/// Spawns a background thread to wait on a child process and reap it when done,
/// preventing zombie (<defunct>) processes.
pub fn reap_child(mut child: std::process::Child) {
    let _ = std::thread::Builder::new()
        .name("proc-reaper".into())
        .spawn(move || {
            let _ = child.wait();
        });
}

/// Spawns a sanitized, detached external command asynchronously and reaps it on exit.
pub fn spawn_detached(cmd: &str) -> std::io::Result<()> {
    let child = build_detached_command(cmd).spawn()?;
    reap_child(child);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_command() {
        let res = parse_command_line("firefox");
        assert_eq!(res, Some(("firefox".to_string(), vec![])));
    }

    #[test]
    fn test_parse_command_with_args() {
        let res = parse_command_line("alacritty -e btop");
        assert_eq!(
            res,
            Some((
                "alacritty".to_string(),
                vec!["-e".to_string(), "btop".to_string()]
            ))
        );
    }

    #[test]
    fn test_parse_command_with_quotes() {
        let res = parse_command_line("notify-send 'Zenith Shell' \"Running smoothly\"");
        assert_eq!(
            res,
            Some((
                "notify-send".to_string(),
                vec!["Zenith Shell".to_string(), "Running smoothly".to_string()]
            ))
        );
    }

    #[test]
    fn test_parse_shell_metachars_fallback() {
        assert_eq!(parse_command_line("cat /etc/os-release | grep NAME"), None);
        assert_eq!(parse_command_line("echo hello > /tmp/out"), None);
        assert_eq!(parse_command_line("sleep 10 &"), None);
        assert_eq!(parse_command_line("a; b"), None);
        assert_eq!(parse_command_line("echo $HOME"), None);
    }

    #[test]
    fn test_spawn_detached_success() {
        let res = spawn_detached("true");
        assert!(res.is_ok());
    }
}
