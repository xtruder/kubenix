{ pkgs ? import <nixpkgs> {}
, kubenix ? import ../. {inherit pkgs;}
, lib ? kubenix.lib
, k8sVersions ? ["1.7" "1.8" "1.9" "1.10" "1.11" "1.12" "1.13"]

# whether any testing error should throw an error
, throwError ? true
, e2e ? true }:

with lib;

let
  images = pkgs.callPackage ./images.nix {};

  tests = listToAttrs (map (version: let
    version' = replaceStrings ["."] ["_"] version;
  in nameValuePair "v${version'}" (evalModules {
    modules = [
      kubenix.testing

      {
        imports = [kubenix.k8s kubenix.submodules];

        kubernetes.version = version;

        testing.throwError = throwError;
        testing.e2e = e2e;
        testing.tests = [
          ./k8s/simple.nix
          ./k8s/deployment.nix
          ./k8s/crd.nix
          ./k8s/1.13/crd.nix
          ./k8s/submodule.nix
          ./submodules/simple.nix
        ];
        testing.defaults = ({kubenix, ...}: {
          imports = [kubenix.k8s];
          kubernetes.version = version;
          _module.args.images = images;
        });
      }
    ];
    args = {
      inherit pkgs;
    };
    specialArgs = {
      inherit kubenix;
    };
  }).config) k8sVersions);
in tests
