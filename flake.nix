{
  description = "Zenith-Shell (Engine v2) — Wayland Desktop Shell Framework in Rust + Luau";

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
        rec {
          zenith-shell = pkgs.rustPlatform.buildRustPackage {
            pname = "zenith-shell";
            version = "0.2.0";
            src = ./.;

            cargoLock = {
              lockFile = ./Cargo.lock;
            };

            cargoBuildFlags = [ "-p" "zenith-cli" ];

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];

            buildInputs = runtimeLibs;

            postInstall = ''
              mkdir -p $out/share/zenith
              cp -r config/zenith/* $out/share/zenith/
            '';

            meta = with pkgs.lib; {
              description = "Zenith Desktop Shell (Engine v2) — Wayland Desktop Shell Framework in Rust + Luau";
              homepage = "https://github.com/lucas/Zenith-Shell";
              license = licenses.mit;
              platforms = platforms.linux;
              mainProgram = "zenith";
            };
          };

          default = zenith-shell;
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
              just
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
