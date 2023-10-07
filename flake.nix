{
  description = "foo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devshell.url = "github:numtide/devshell";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:guibou/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, ...} @ inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      perSystem = {
        config,
        system,
        lib,
        ...
      }: let
        overlays = [(import inputs.rust-overlay) (inputs.nixgl.overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rustPlatform = pkgs.makeRustPlatform {
          rustc = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
          cargo = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
        };
      in {
        devShells.default = pkgs.mkShell {
          inputsFrom = [config.packages.universal-android-debloater];
          packages = with pkgs; [
            taplo
            pkgs.nixgl.auto.nixGLDefault
          ];
          LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib:" + lib.makeLibraryPath [pkgs.freetype.dev pkgs.fontconfig.lib];
        };
        packages =
          rec {
            universal-android-debloater = rustPlatform.buildRustPackage {
              doCheck = false;
              pname = "universal-android-debloater";
              version = "0.1.0";
              src = ./.;
              cargoLock = {
                lockFile = ./Cargo.lock;
                outputHashes = {
                  "glutin-0.29.1" = "sha256-5jGYf2jR0nKZ6/h6/kH5wXfSTIaMXGC8XdVz/HBSMs8=";
                  "iced-0.8.0" = "sha256-y7J1GyN+GAMFHh1fy0wHxHsqu6MVQwoWdFc/DcdygHw=";
                  "winit-0.27.2" = "sha256-mv/6oANQnyBjMbuemRBpDAVLRUURgGxv4KH1I71Wtpw=";
                };
              };
              nativeBuildInputs = with pkgs; [
                pkg-config
                wrapGAppsHook4
                rustPlatform.bindgenHook
                clang
                mold
                freetype.out
              ];
              buildInputs = with pkgs; [
                android-tools
                gobject-introspection
                gtk4
                glib-networking
                # WINIT_UNIX_BACKEND=wayland
                wayland

                libxkbcommon
                libGL
                # WINIT_UNIX_BACKEND=x11
                xorg.libXcursor
                xorg.libXrandr
                xorg.libXi
                xorg.libX11

                glslang
                vulkan-headers
                vulkan-loader
                vulkan-validation-layers
                mesa.drivers
                freetype.out expat

              ];
            };
            universal-android-debloater-wrapped = pkgs.symlinkJoin rec {
              name = "uad_gui";
              paths = [universal-android-debloater];
              buildInputs = [pkgs.makeWrapper];
              postBuild = ''
                wrapProgram $out/bin/${name} \
                  --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [pkgs.freetype.out pkgs.expat] + ":/run/opengl-driver/lib:/run/opengl-driver-32/lib:" }
              '';
            };
          }
          // {default = config.packages.universal-android-debloater-wrapped;};
        formatter = pkgs.alejandra;
      };
    };
}
