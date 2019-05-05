{ pkgs ? import <nixpkgs> {}, nixosPath ? toString <nixpkgs/nixos>, lib ? pkgs.lib
, e2e ? true, throwError ? true }:

with lib;

let
  kubenix = import ./. { inherit pkgs; };

  lib = kubenix.lib;

  generateK8S = spec: import ./generators/k8s {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit spec;
  };

  generateIstio = import ./generators/istio {
    inherit pkgs;
    inherit (pkgs) lib;
  };

  runK8STests = k8sVersion: pkgs.recurseIntoAttrs (getAttrs ["result" "results" "success"]
    (import ./tests {
      inherit pkgs lib kubenix k8sVersion e2e throwError nixosPath;
    })
  );
in rec {
  generate.k8s = pkgs.linkFarm "k8s-generated.nix" [{
    name = "v1.7.nix";
    path = generateK8S "${pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      rev = "v1.7.16";
      sha256 = "1ksalw3hzbcca89n9h3pas9nqj2n5gq3rbpdx633ycqb8g46h1iw";
    }}/api/openapi-spec/swagger.json";
  } {
    name = "v1.8.nix";
    path = generateK8S "${pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      rev = "v1.8.15";
      sha256 = "1mwaafnkimr4kwqws4qli11wbavpmf27i6pjq77sfsapw9sz54j4";
    }}/api/openapi-spec/swagger.json";
  } {
    name = "v1.9.nix";
    path = generateK8S "${pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      rev = "v1.9.11";
      sha256 = "1wl944ci7k8knrkdrc328agyq4c953j9dm0sn314s42j18lfd7rv";
    }}/api/openapi-spec/swagger.json";
  } {
    name = "v1.10.nix";
    path = generateK8S "${pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      rev = "v1.10.13";
      sha256 = "07hwcamlc1kh5flwv4ahfkcg2lyhnbs8q2xczaws6v3sjxaycrrn";
    }}/api/openapi-spec/swagger.json";
  } {
    name = "v1.11.nix";
    path = generateK8S "${pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      rev = "v1.11.8";
      sha256 = "1q6x38zdycd4ai31gn666hg41bs4q32dyz2d07x76hj33fkzqs1f";
    }}/api/openapi-spec/swagger.json";
  } {
    name = "v1.12.nix";
    path = generateK8S "${pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      rev = "v1.12.6";
      sha256 = "0p9wh264xfm4c0inz99jclf603c414807vn19gfn62bfls3jcmgf";
    }}/api/openapi-spec/swagger.json";
  } {
    name = "v1.13.nix";
    path = generateK8S "${pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      rev = "v1.13.4";
      sha256 = "1q3dc416fr9nzy64pl7rydahygnird0vpk9yflssw7v9gx84m6x9";
    }}/api/openapi-spec/swagger.json";
  }];

  generate.istio = pkgs.linkFarm "istio-generated.nix" [{
    name = "latest.nix";
    path = generateIstio;
  }];

  tests = pkgs.recurseIntoAttrs {
    k8s-1_7 = runK8STests "1.7";
    k8s-1_8 = runK8STests "1.8";
    k8s-1_9 = runK8STests "1.9";
    k8s-1_10 = runK8STests "1.10";
    k8s-1_11 = runK8STests "1.11";
    k8s-1_12 = runK8STests "1.12";
    k8s-1_13 = runK8STests "1.13";
  };

  test-check =
    if !(all (test: if isAttrs test then test.success else true) (attrValues tests))
    then throw "tests failed"
    else true;

  examples = import ./examples {};
}
