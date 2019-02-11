{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

let
  lib' = lib.extend (lib: self: import ./lib.nix { inherit lib pkgs; });

  specialArgs = {
    inherit kubenix;
  };

  evalKubernetesModules = configuration: lib'.evalModules rec {
    modules = [
      configuration
    ];
    args = {
      inherit pkgs;
      name = "default";
    };
    inherit specialArgs;
  };

  buildResources = configuration:
    (evalKubernetesModules configuration).config.kubernetes.generated;

  kubenix = {
    inherit buildResources kubenix;

    lib = lib';
    submodules = ./submodules.nix;
    k8s = ./k8s;
    istio = ./istio;
  };
in kubenix
