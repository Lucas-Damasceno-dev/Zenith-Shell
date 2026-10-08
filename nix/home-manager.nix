{ self, quickshell }:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.programs.zenith-shell;
  system = pkgs.stdenv.hostPlatform.system;

  zenith-pkg = (self.packages.${system}.zenith-shell or pkgs.zenith-shell);

  runtimeDeps = with pkgs; [
    bash
    coreutils
    procps
    systemd
    networkmanager
    playerctl
    upower
    pipewire
    wireplumber
    hyprland
  ];
in
{
  options.programs.zenith-shell = {
    enable = mkEnableOption "Zenith-Shell (Engine v2) — Wayland Desktop Shell in Rust + Luau";

    package = mkOption {
      type = types.package;
      default = zenith-pkg;
      description = "Zenith shell package to install";
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

    xdg.configFile."zenith" = mkIf (cfg.configDir != null) {
      source = if cfg.enableLiveSymlink then
        config.lib.file.mkOutOfStoreSymlink cfg.configDir
      else
        cfg.configDir;
      recursive = !cfg.enableLiveSymlink;
    };

    systemd.user.services.zenith-shell = mkIf cfg.enableSystemd {
      Unit = {
        Description = "Zenith Desktop Shell (Engine v2)";
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
        MemoryMax = "50M";
        MemoryHigh = "35M";
        CPUWeight = 200;
        Environment = [
          "PATH=${cfg.package}/bin:${lib.makeBinPath runtimeDeps}"
        ];
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
