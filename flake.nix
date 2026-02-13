{
  description = "nix-openclaw: declarative OpenClaw packaging";

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-steipete-tools.url = "github:openclaw/nix-steipete-tools";
  };

  outputs = { self, nixpkgs, flake-utils, home-manager, nix-steipete-tools }:
    let
      overlay = import ./nix/overlay.nix;
      sourceInfoStable = import ./nix/sources/openclaw-source.nix;
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      bundledPluginInputs = {
        summarize = nix-steipete-tools;
        peekaboo = nix-steipete-tools;
        oracle = nix-steipete-tools;
        poltergeist = nix-steipete-tools;
        sag = nix-steipete-tools;
        camsnap = nix-steipete-tools;
        gogcli = nix-steipete-tools;
        goplaces = nix-steipete-tools;
        bird = nix-steipete-tools;
        sonoscli = nix-steipete-tools;
        imsg = nix-steipete-tools;
      };

      openclawLib = import ./nix/lib { inherit (nixpkgs) lib; };
    in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
        steipetePkgs = if nix-steipete-tools ? packages && builtins.hasAttr system nix-steipete-tools.packages
          then nix-steipete-tools.packages.${system}
          else {};
        packageSetStable = import ./nix/packages {
          pkgs = pkgs;
          sourceInfo = sourceInfoStable;
          steipetePkgs = steipetePkgs;
        };
        openclawModule = import ./nix/modules/home-manager/openclaw.nix {
          inherit bundledPluginInputs;
          inherit (openclawLib.openclaw) resolvePlugin;
        };
      in
      {
        packages = packageSetStable // {
          default = packageSetStable.openclaw;
          openclaw-gateway-wrapped = pkgs.callPackage ./nix/packages/openclaw-gateway-wrapped.nix {
            openclaw-gateway = packageSetStable.openclaw-gateway;
          };
        };

        apps = {
          openclaw = flake-utils.lib.mkApp { drv = packageSetStable.openclaw-gateway; };
        };

        checks = {
          gateway = packageSetStable.openclaw-gateway;
          package-contents = pkgs.callPackage ./nix/checks/openclaw-package-contents.nix {
            openclawGateway = packageSetStable.openclaw-gateway;
          };
          config-validity = pkgs.callPackage ./nix/checks/openclaw-config-validity.nix {
            openclawGateway = packageSetStable.openclaw-gateway;
            inherit openclawModule;
          };
        } // (if pkgs.stdenv.hostPlatform.isLinux then {
          gateway-tests = pkgs.callPackage ./nix/checks/openclaw-gateway-tests.nix {
            sourceInfo = sourceInfoStable;
          };
          config-options = pkgs.callPackage ./nix/checks/openclaw-config-options.nix {
            sourceInfo = sourceInfoStable;
            inherit openclawModule;
          };
          default-instance = pkgs.callPackage ./nix/checks/openclaw-default-instance.nix {
            inherit openclawModule;
          };
          hm-activation = import ./nix/checks/openclaw-hm-activation.nix {
            inherit pkgs home-manager openclawModule;
          };
        } else {});

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.nixfmt-rfc-style
            pkgs.nil
          ];
        };
      }
    ) // {
      lib = openclawLib;

      overlays.default = overlay;
      homeManagerModules.openclaw = import ./nix/modules/home-manager/openclaw.nix {
        inherit bundledPluginInputs;
        inherit (openclawLib.openclaw) resolvePlugin;
      };
      darwinModules.openclaw = import ./nix/modules/darwin/openclaw.nix {
        hmModule = self.homeManagerModules.openclaw;
      };
    };
}
