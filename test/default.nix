{ pkgs ? import <nixpkgs> {}
, kubenix ? import ../. {inherit pkgs;}
, lib ? kubenix.lib

# whether any testing error should throw an error
, throwError ? true }:

with lib;

(evalModules {
  modules = [
    ./modules/testing.nix

    {
      testing.throwError = throwError;
      testing.tests = [
        ./k8s/simple.nix
        ./k8s/deployment.nix
      ];
    }
  ];
  args = {
    inherit pkgs;
  };
  specialArgs = {
    inherit kubenix;
  };
}).config.testing.result
