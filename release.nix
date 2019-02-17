{pkgs ? import <nixpkgs> {}}:

let
  kubenix = import ./. { inherit pkgs; };

  lib = kubenix.lib;

  generateK8S = spec: import ./k8s/generator.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit spec;
  };

  generateIstio = spec: import ./istio/generator.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit spec;
  };
in {
  generate.k8s = pkgs.linkFarm "k8s-generated.nix" [{
    name = "v1.7.nix";
    path = generateK8S ./k8s/specs/1.7/swagger.json;
  } {
    name = "v1.8.nix";
    path = generateK8S ./k8s/specs/1.8/swagger.json;
  } {
    name = "v1.9.nix";
    path = generateK8S ./k8s/specs/1.9/swagger.json;
  } {
    name = "v1.10.nix";
    path = generateK8S ./k8s/specs/1.10/swagger.json;
  } {
    name = "v1.11.nix";
    path = generateK8S ./k8s/specs/1.11/swagger.json;
  } {
    name = "v1.12.nix";
    path = generateK8S ./k8s/specs/1.12/swagger.json;
  } {
    name = "v1.13.nix";
    path = generateK8S ./k8s/specs/1.13/swagger.json;
  }];

  generate.istio = pkgs.linkFarm "istio-generated.nix" [{
    name = "latest.nix";
    path = generateIstio ./istio/istio-schema.json;
  }];

  tests = import ./tests {
    inherit pkgs lib kubenix;
  };
}
