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

    bundled-plugin-summarize.url = "github:openclaw/nix-steipete-tools?dir=tools/summarize";
    bundled-plugin-summarize.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-peekaboo.url = "github:openclaw/nix-steipete-tools?dir=tools/peekaboo";
    bundled-plugin-peekaboo.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-oracle.url = "github:openclaw/nix-steipete-tools?dir=tools/oracle";
    bundled-plugin-oracle.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-poltergeist.url = "github:openclaw/nix-steipete-tools?dir=tools/poltergeist";
    bundled-plugin-poltergeist.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-sag.url = "github:openclaw/nix-steipete-tools?dir=tools/sag";
    bundled-plugin-sag.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-camsnap.url = "github:openclaw/nix-steipete-tools?dir=tools/camsnap";
    bundled-plugin-camsnap.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-gogcli.url = "github:openclaw/nix-steipete-tools?dir=tools/gogcli";
    bundled-plugin-gogcli.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-goplaces.url = "github:openclaw/nix-steipete-tools?dir=tools/goplaces";
    bundled-plugin-goplaces.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-bird.url = "github:openclaw/nix-steipete-tools?dir=tools/bird";
    bundled-plugin-bird.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-sonoscli.url = "github:openclaw/nix-steipete-tools?dir=tools/sonoscli";
    bundled-plugin-sonoscli.inputs.nixpkgs.follows = "nixpkgs";
    bundled-plugin-imsg.url = "github:openclaw/nix-steipete-tools?dir=tools/imsg";
    bundled-plugin-imsg.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, home-manager, nix-steipete-tools, ... }:
    let
      overlay = import ./nix/overlay.nix;
      sourceInfoStable = import ./nix/sources/openclaw-source.nix;
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      bundledPluginInputs = {
        summarize = inputs."bundled-plugin-summarize";
        peekaboo = inputs."bundled-plugin-peekaboo";
        oracle = inputs."bundled-plugin-oracle";
        poltergeist = inputs."bundled-plugin-poltergeist";
        sag = inputs."bundled-plugin-sag";
        camsnap = inputs."bundled-plugin-camsnap";
        gogcli = inputs."bundled-plugin-gogcli";
        goplaces = inputs."bundled-plugin-goplaces";
        bird = inputs."bundled-plugin-bird";
        sonoscli = inputs."bundled-plugin-sonoscli";
        imsg = inputs."bundled-plugin-imsg";
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
