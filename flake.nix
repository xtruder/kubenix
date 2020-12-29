{
  description = "Kubernetes resource builder using nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        packages.kubenix = pkgs.callPackage ./default.nix {
          inherit pkgs;
          nixosPath = "${nixpkgs}/nixos";
        };
        defaultPackage = packages.kubenix;
      });
}
