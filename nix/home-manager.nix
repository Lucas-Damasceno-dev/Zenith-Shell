{ self, quickshell }:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.programs.zenith-shell;
  system = pkgs.stdenv.hostPlatform.system;

  quickshell-pkg = (quickshell.packages.${system}.default or pkgs.quickshell).withModules [
    pkgs.qt6.qtsvg
    pkgs.qt6.qtimageformats
    pkgs.qt6.qtmultimedia
    pkgs.qt6.qt5compat
    pkgs.pipewire
    pkgs.libpulseaudio
  ];

  qsRuntimeDeps = with pkgs; [
    bash coreutils findutils fd gnugrep gawk jq procps file
    git curl socat expect
    systemd util-linux udisks2
    networkmanager bluez playerctl upower power-profiles-daemon
    brightnessctl grim slurp wf-recorder hyprpicker swappy wl-clipboard awww gnused
    tesseract libnotify xdg-utils imagemagick cliphist
    pipewire wireplumber pulseaudio hyprland
    (python3.withPackages (ps: [ ps.dbus-fast ps.requests ]))
  ];
in
{
  options.programs.zenith-shell = {
    enable = mkEnableOption "Zenith-Shell Quickshell & Hyprland Rice";

    terminal = mkOption {
      type = types.str;
      default = "kitty";
      description = "Default terminal emulator";
    };

    browser = mkOption {
      type = types.str;
      default = "brave";
      description = "Default web browser";
    };

    fileManager = mkOption {
      type = types.str;
      default = "thunar";
      description = "Default graphical file manager";
    };

    enableSystemdServices = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable quickshell and context daemon systemd user services";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ quickshell-pkg ] ++ qsRuntimeDeps;

    xdg.configFile."quickshell".source = ../config/quickshell;
    xdg.configFile."hypr".source = ../config/hypr;

    systemd.user.services.quickshell = mkIf cfg.enableSystemdServices {
      Unit = {
        Description = "Zenith-Shell Desktop Environment";
        After = [ "graphical-session.target" "hyprland-session.target" ];
        PartOf = [ "hyprland-session.target" ];
        ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
      };
      Service = {
        Type = "simple";
        ExecStart = "${quickshell-pkg}/bin/quickshell --no-duplicate";
        Restart = "on-failure";
        RestartSec = 3;
        Slice = "session.slice";
        MemoryMax = "800M";
        MemoryHigh = "700M";
        CPUWeight = 200;
        Environment = [
          "QT_QPA_PLATFORM=wayland"
          "QT_WAYLAND_DISABLE_WINDOWDECORATION=1"
          "QT_ICON_THEME=Papirus-Dark"
          "PATH=${quickshell-pkg}/bin:${lib.makeBinPath qsRuntimeDeps}"
        ];
      };
      Install = {
        WantedBy = [ "hyprland-session.target" ];
      };
    };

    systemd.user.services.zenith-context-daemon = mkIf cfg.enableSystemdServices {
      Unit = {
        Description = "Zenith-Shell Context & Connectivity Daemon";
        After = [ "graphical-session.target" "hyprland-session.target" ];
        PartOf = [ "hyprland-session.target" ];
        ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.python3.withPackages (ps: [ ps.dbus-fast ps.requests ])}/bin/python3 ${config.home.homeDirectory}/.config/quickshell/scripts/daemon/context_daemon_v2.py";
        Restart = "on-failure";
        RestartSec = 2;
        Slice = "session.slice";
        MemoryMax = "250M";
        CPUQuota = "20%";
        Environment = [
          "PATH=${quickshell-pkg}/bin:${lib.makeBinPath qsRuntimeDeps}"
          "PYTHONUNBUFFERED=1"
        ];
      };
      Install = {
        WantedBy = [ "hyprland-session.target" ];
      };
    };
  };
}
