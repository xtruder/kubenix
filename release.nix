let
  fetch = import ./lib/compat.nix;
in
{ pkgs ? import (fetch "nixpkgs") { }
, nixosPath ? toString (fetch "nixpkgs") + "/nixos"
, lib ? pkgs.lib
, throwError ? true
}:

with lib;

let
  kubenix = import ./. { inherit pkgs; };

  lib = kubenix.lib;

  generateK8S = name: spec: import ./generators/k8s {
    inherit name;
    inherit pkgs;
    inherit (pkgs) lib;
    inherit spec;
  };

  generateIstio = import ./generators/istio {
    inherit pkgs;
    inherit (pkgs) lib;
  };

  runK8STests = k8sVersion: import ./tests {
    inherit pkgs lib kubenix k8sVersion throwError nixosPath;
  };
in
rec {
  generate.k8s = pkgs.linkFarm "k8s-generated.nix" [
    {
      name = "v1.19.nix";
      path = generateK8S "v1.19" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.19.10/api/openapi-spec/swagger.json";
        sha256 = "sha256-ZXxonUAUxRK6rhTgK62ytTdDKCuOoWPwxJmktiKgcJc=";
      });
    }

    {
      name = "v1.20.nix";
      path = generateK8S "v1.20" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.20.6/api/openapi-spec/swagger.json";
        sha256 = "sha256-xzVOarQDSomHMimpt8H6MfpiQrLl9am2fDvk/GfLkDw=";
      });
    }

    {
      name = "v1.21.nix";
      path = generateK8S "v1.21" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.21.0/api/openapi-spec/swagger.json";
        sha256 = "sha256-EoqYTbtaTlzs7vneoNtXUmdnjTM/U+1gYwCiEy0lOcw=";
      });
    }
  ];

  generate.istio = pkgs.linkFarm "istio-generated.nix" [{
    name = "latest.nix";
    path = generateIstio;
  }];

  tests = {
    k8s-1_19 = runK8STests "1.19";
    k8s-1_20 = runK8STests "1.20";
    k8s-1_21 = runK8STests "1.21";
  };

  test-check =
    if !(all (test: test.success) (attrValues tests))
    then throw "tests failed"
    else true;

  examples = import ./examples { };
}
