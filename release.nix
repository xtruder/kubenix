{ pkgs ? import <nixpkgs> {}, nixosPath ? toString <nixpkgs/nixos>, lib ? pkgs.lib
, e2e ? true, throwError ? true }:

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

  runK8STests = k8sVersion: import ./tests {
    inherit pkgs lib kubenix k8sVersion e2e throwError nixosPath;
  };
in rec {
  generate.k8s = pkgs.linkFarm "k8s-generated.nix" [
    {
      name = "v1.19.nix";
      path = generateK8S "v1.19" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.19.0/api/openapi-spec/swagger.json";
        sha256 = "15vhl0ibd94rqkq678cf5cl46dxmnanjpq0lmsx15i8l82fnhz35";
      });
    }

    {
      name = "v1.20.nix";
      path = generateK8S "v1.20" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.20.0/api/openapi-spec/swagger.json";
        sha256 = "0g4hrdkzrr1vgjvakxg5n9165yiizb0vga996a3qjjh3nim4wdf7";
      });
    }

    {
      name = "v1.21.nix";
      path = generateK8S "v1.21" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.21.0/api/openapi-spec/swagger.json";
        sha256 = "1k1r4lni78h0cdhfslrz6f6nfrsjazds1pprxvn5qkjspd6ri2hj";
      });
    }

    {
      name = "v1.22.nix";
      path = generateK8S "v1.22" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.22.0/api/openapi-spec/swagger.json";
        sha256 = "0ww7blb13001p4lcdjmbzmy1871i5ggxmfg2r56iws32w1q8cwfn";
      });
    }

    {
      name = "v1.23.nix";
      path = generateK8S "v1.23" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.23.0/api/openapi-spec/swagger.json";
        sha256 = "0jivg8nlxka1y7gzqpcxkmbvhcbxynyrxmjn0blky30q5064wx2a";
      });
    }
  ];

  tests = {
    k8s-1_19 = runK8STests "1.19";
    k8s-1_20 = runK8STests "1.20";
    k8s-1_21 = runK8STests "1.21";
    k8s-1_22 = runK8STests "1.22";
    k8s-1_23 = runK8STests "1.23";
  };

  test-results = pkgs.recurseIntoAttrs (mapAttrs (_: t: pkgs.recurseIntoAttrs {
    results = pkgs.recurseIntoAttrs t.results;
    result = t.result;
  }) tests);

  test-check =
    if !(all (test: test.success) (attrValues tests))
    then throw "tests failed"
    else true;

  examples = import ./examples {};
}
