{
  description = "Kubernetes resource builder using nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils }:
    { nixosModules = import ./modules; }
    //
    (flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlay
            ];
            config = { };
          };
        in
        rec {
          devShell = with pkgs; mkShell {
            buildInputs = [
            ];
          };

          packages = flake-utils.lib.flattenTree {
            inherit (pkgs)
              kubenix
              ;
          };

          hydraJobs = {
            inherit packages;
          };
        }
      )
    ) //
    {
      overlay = final: prev: {
        kubenix = prev.callPackage ./default.nix {
          nixosPath = "${nixpkgs}/nixos";
        };
      };
    };
}
