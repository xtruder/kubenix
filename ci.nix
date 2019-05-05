let
  nixpkgsSrc = builtins.fetchTarball "https://github.com/NixOS/nixpkgs-channels/archive/nixos-unstable.tar.gz";
  pkgs = import nixpkgsSrc {};

  lib = pkgs.lib;

  release = import ./release.nix {
    inherit pkgs lib;
    e2e = false;
    nixosPath = "${nixpkgsSrc}/nixos";
  };
in with lib; release.tests
