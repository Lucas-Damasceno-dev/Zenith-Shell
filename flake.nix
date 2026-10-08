{
  description = "Zenith-Shell — Next-Gen Desktop Shell & Rice powered by Hyprland and Rust+Luau Engine";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, quickshell, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runtimeLibs = with pkgs; [
            wayland
            libxkbcommon
            vulkan-loader
            libGL
            dbus
            pipewire
            fontconfig
            freetype
          ];
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "zenith-shell";
            version = "1.0.0";
            src = ./.;
            installPhase = ''
              mkdir -p $out/share/zenith-shell
              cp -r config systemd install.sh $out/share/zenith-shell/
            '';
          };
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runtimeLibs = with pkgs; [
            wayland
            libxkbcommon
            vulkan-loader
            libGL
            dbus
            pipewire
            fontconfig
            freetype
          ];
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              cargo
              rustc
              rustfmt
              clippy
              rust-analyzer
              pkg-config
            ];
            buildInputs = runtimeLibs;
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;
          };
        }
      );

      homeManagerModules.default = import ./nix/home-manager.nix { inherit self quickshell; };
      homeManagerModules.zenith-shell = self.homeManagerModules.default;
    };
}
