{
  description = "Zenith-Shell (Engine Base v3) — Wayland Desktop Shell Framework in Rust + Luau";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
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
            version = "0.3.0";
            src = ./.;

            cargoLock = {
              lockFile = ./Cargo.lock;
            };

            cargoBuildFlags = [ "-p" "zenith-cli" ];

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];

            buildInputs = runtimeLibs;

            FONTCONFIG_FILE = pkgs.makeFontsConf {
              fontDirectories = [ pkgs.dejavu_fonts ];
            };

            nativeCheckInputs = with pkgs; [
              dejavu_fonts
              fontconfig
            ];

            postInstall = ''
              mkdir -p $out/share/zenith
              cp -r config/zenith/* $out/share/zenith/
              ln -sf $out/bin/zenith $out/bin/zenith-cli
            '';

            meta = with pkgs.lib; {
              description = "Zenith Desktop Shell (Engine Base v3) — Wayland Desktop Shell Framework in Rust + Luau";
              homepage = "https://github.com/Lucas-Damasceno-dev/Zenith-Shell";
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

      homeManagerModules.default = import ./nix/home-manager.nix { inherit self; };
      homeManagerModules.zenith-shell = self.homeManagerModules.default;
    };
}
