{ pkgs ? import <nixpkgs> {}, nixosPath ? toString <nixpkgs/nixos>, lib ? pkgs.lib }:

with lib;

let
  kubenixLib = import ./lib { inherit lib pkgs; };
  lib' = lib.extend (lib: self: import ./lib/extra.nix { inherit lib pkgs; });

  defaultSpecialArgs = {
    inherit kubenix nixosPath;
  };

  # evalModules with same interface as lib.evalModules and kubenix as
  # special argument
  evalModules = {
    args ? {},
    check ? false,
    module ? null,
    modules ? [module],
    specialArgs ? defaultSpecialArgs, ...
  }@attrs: let
    attrs' = builtins.removeAttrs attrs [ "args" "check" "module" ];
  in lib'.evalModules (recursiveUpdate {
    specialArgs = specialArgs // { inherit pkgs; };
    modules = [
      {
        _module = {
          inherit check;
          args = recursiveUpdated {
            name = "default";
          };
        } args;
      }
    ] ++ modules;
  } attrs');

  modules = import ./modules;

  # legacy support for buildResources
  buildResources = {
    configuration ? {},
    writeJSON ? true,
    writeHash ? true
  }: let
    evaled = evalModules {
      modules = [
        configuration
        modules.legacy
      ];
    };

    generated = evaled.config.kubernetes.generated;

    result =
      if writeJSON
      then pkgs.writeText "resources.json" (builtins.toJSON generated)
      else generated;
  in result;

  kubenix = {
    inherit evalModules buildResources modules;

    lib = kubenixLib;
  };
in kubenix
