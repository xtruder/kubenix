let
  nixpkgsSrc = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz";
  pkgs = import nixpkgsSrc {};

  lib = pkgs.lib;

  release = import ./release.nix {
    inherit pkgs lib;
    nixosPath = "${nixpkgsSrc}/nixos";
  };
in pkgs.recurseIntoAttrs release
