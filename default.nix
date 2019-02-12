{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

let
  lib' = lib.extend (lib: self: import ./lib.nix { inherit lib pkgs; });

  specialArgs' = {
    inherit kubenix;
  };

  evalKubernetesModules = {module ? null, modules ? [module], specialArgs ? specialArgs', ...}@attrs: let
    attrs' = lib.filterAttrs (n: _: n != "module") attrs;
  in lib'.evalModules (attrs' // {
    inherit specialArgs modules;
    args = {
      inherit pkgs;
      name = "default";
    };
  });

  buildResources = args:
    (evalKubernetesModules args).config.kubernetes.generated;

  kubenix = {
    inherit evalKubernetesModules buildResources kubenix;

    lib = lib';
    submodules = ./submodules.nix;
    k8s = ./k8s;
    istio = ./istio;
  };
in kubenix
