//! Zenith-CLI wrapper binary forwarding to the primary zenith executable.

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<std::ffi::OsString> = std::env::args_os().skip(1).collect();
    let self_exe = std::env::current_exe()?;
    let zenith_bin = self_exe
        .parent()
        .map(|p| p.join("zenith"))
        .unwrap_or_else(|| std::path::PathBuf::from("zenith"));

    let status = if zenith_bin.exists() {
        std::process::Command::new(zenith_bin).args(&args).status()?
    } else {
        std::process::Command::new("zenith").args(&args).status()?
    };

    std::process::exit(status.code().unwrap_or(0));
}
