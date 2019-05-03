let
  pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs-channels/archive/nixos-unstable.tar.gz") {};

  lib = pkgs.lib;

  release = import ./release.nix { inherit pkgs lib; };
in with lib; release.test-results
