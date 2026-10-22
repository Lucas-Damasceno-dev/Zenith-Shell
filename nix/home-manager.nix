{ self, ... }:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.programs.zenith-shell;
  system = pkgs.stdenv.hostPlatform.system;

  zenith-pkg = (self.packages.${system}.zenith-shell or pkgs.zenith-shell);

  runtimeDeps = with pkgs; [
    # Minimal runtime dependencies: native engine handles D-Bus (zbus) and sockets directly
    pipewire
    wireplumber
    hyprland
    wl-clipboard
    cliphist
    grim
    slurp
  ];
in
{
  options.programs.zenith-shell = {
    enable = mkEnableOption "Zenith-Shell (Engine Base v3) — Wayland Desktop Shell in Rust + Luau";

    package = mkOption {
      type = types.package;
      default = zenith-pkg;
      description = "Zenith shell package to install";
    };

    devPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/home/lucas/Documents/03_Desenvolvimento/code/projects/personal/portfolio/desktop/Zenith-Shell/config/zenith";
      description = "Absolute path to local mutable Zenith repository config directory for sub-10ms hot-reload via mkOutOfStoreSymlink.";
    };

    configDir = mkOption {
      type = types.nullOr types.path;
      default = ../config/zenith;
      description = "Path to Zenith declarative Luau configurations";
    };

    enableLiveSymlink = mkOption {
      type = types.bool;
      default = true;
      description = "Symlink config directly into ~/.config/zenith for sub-10ms live iteration without rebuilding";
    };

    enableSystemd = mkOption {
      type = types.bool;
      default = true;
      description = "Enable systemd user service for Zenith Shell";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ] ++ runtimeDeps;

    xdg.configFile."zenith" = mkIf (cfg.devPath != null || cfg.configDir != null) {
      source =
        if cfg.enableLiveSymlink && cfg.devPath != null then
          config.lib.file.mkOutOfStoreSymlink cfg.devPath
        else if cfg.configDir != null then
          cfg.configDir
        else
          "${cfg.package}/share/zenith";
      recursive = !(cfg.enableLiveSymlink && cfg.devPath != null);
    };

    systemd.user.services.zenith-shell = mkIf cfg.enableSystemd {
      Unit = {
        Description = "Zenith Desktop Shell (Engine Base v3)";
        After = [ "graphical-session.target" "hyprland-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/zenith daemon ${config.home.homeDirectory}/.config/zenith/bar.luau";
        ExecReload = "${cfg.package}/bin/zenith reload";
        Restart = "on-failure";
        RestartSec = 2;
        Slice = "session.slice";
        MemoryMax = "180M";
        MemoryHigh = "120M";
        CPUWeight = 200;
        Environment = [
          "PATH=${cfg.package}/bin:${lib.makeBinPath runtimeDeps}"
          "ZENITH_CONFIG_DIR=${config.home.homeDirectory}/.config/zenith"
          "MALLOC_ARENA_MAX=2"
        ];
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
