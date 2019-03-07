{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

with lib;

let
  kubenixLib = import ./lib { inherit lib pkgs; };
  lib' = lib.extend (lib: self: import ./lib/extra.nix { inherit lib pkgs; });

  defaultSpecialArgs = {
    inherit kubenix;
  };

  evalModules = {
    module ? null,
    modules ? [module],
    specialArgs ? defaultSpecialArgs, ...
  }@attrs: let
    attrs' = filterAttrs (n: _: n != "module") attrs;
  in lib'.evalModules (attrs' // {
    inherit specialArgs modules;
    args = {
      inherit pkgs;
      name = "default";
    };
  });

  modules = import ./modules;

  kubenix = {
    inherit evalModules kubenix;

    lib = kubenixLib;
  } // modules;
in kubenix
