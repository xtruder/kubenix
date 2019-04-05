{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, kubenix ? import ../. { inherit pkgs lib; }
, k8sVersion ? "1.13"

# whether any testing error should throw an error
, throwError ? true
, e2e ? true }:

with lib;

let
  images = pkgs.callPackage ./images.nix {};

  test = (kubenix.evalModules {
    modules = [
      kubenix.modules.testing

      {
        testing.throwError = throwError;
        testing.e2e = e2e;
        testing.tests = [
          ./k8s/simple.nix
          ./k8s/deployment.nix
          ./k8s/crd.nix
          ./k8s/1.13/crd.nix
          ./k8s/defaults.nix
          ./k8s/order.nix
          ./k8s/submodule.nix
          ./k8s/imports.nix
          ./helm/simple.nix
          ./istio/bookinfo.nix
          ./submodules/simple.nix
          ./submodules/defaults.nix
          ./submodules/versioning.nix
        ];
        testing.args = {
          inherit images k8sVersion;
        };
      }
    ];
    args = {
      inherit pkgs;
    };
    specialArgs = {
      inherit kubenix;
    };
  }).config;
in test.testing
