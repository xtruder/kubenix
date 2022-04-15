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

  generateIstio = import ./generators/istio {
    inherit pkgs;
    inherit (pkgs) lib;
  };

  runK8STests = k8sVersion: import ./tests {
    inherit pkgs lib kubenix k8sVersion e2e throwError nixosPath;
  };
in rec {
  generate.k8s = pkgs.linkFarm "k8s-generated.nix" [
    {
      name = "v1.8.nix";
      path = generateK8S "v1.8" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.8.15/api/openapi-spec/swagger.json";
        sha256 = "112c64gq6ksskzqscgwj8l30mq80w2ha9skpz5ixgvjjz6amylh8";
      });
    }

    {
      name = "v1.9.nix";
      path = generateK8S "v1.9" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.9.11/api/openapi-spec/swagger.json";
        sha256 = "0x3ka044ii39ln0f8q2m3w9vwd4vf3bsmbwkc793bkw46w879vvq";
      });
    }

    {
      name = "v1.10.nix";
      path = generateK8S "v1.10" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.10.13/api/openapi-spec/swagger.json";
        sha256 = "133ldlrlh9yfgp39ij1qm9mwlb92igbnxf5flfm1ffifdsd5j3hy";
      });
    }

    {
      name = "v1.11.nix";
      path = generateK8S "v1.11" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.11.8/api/openapi-spec/swagger.json";
        sha256 = "1c7wjvi5rh69lpm373jp3z1dqzyzgkk5csr8qxw0pqr26bhr7w6s";
      });
    }

    {
      name = "v1.12.nix";
      path = generateK8S "v1.12" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.12.6/api/openapi-spec/swagger.json";
        sha256 = "1bmvmwd8jakh5q2rcf17y4fdn1pb4srvcm816m9q5kavz60wdbkx";
      });
    }

    {
      name = "v1.13.nix";
      path = generateK8S "v1.13" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.13.4/api/openapi-spec/swagger.json";
        sha256 = "158izzjlq3qayhfg2ns5w6nwwn11gzxn1pyyxjz6rvvk526drs92";
      });
    }

    {
      name = "v1.14.nix";
      path = generateK8S "v1.14" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.14.10/api/openapi-spec/swagger.json";
        sha256 = "017jf5pr559d3a6cacbz79c892fh50iz7f0zcg8iwsr5af10h8xr";
      });
    }

    {
      name = "v1.15.nix";
      path = generateK8S "v1.15" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.15.7/api/openapi-spec/swagger.json";
        sha256 = "0lrya0i632xjdyr92q8hriifk6xr8cbv2qymfcrshrmx1a45h0kp";
      });
    }

    {
      name = "v1.16.nix";
      path = generateK8S "v1.16" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.16.8/api/openapi-spec/swagger.json";
        sha256 = "06rh8phsdfvw0mg5nxnnpqfxfmgcka4rq64ardyzns0s2kv6x8l3";
      });
    }

    {
      name = "v1.17.nix";
      path = generateK8S "v1.17" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.17.4/api/openapi-spec/swagger.json";
        sha256 = "1yljdpi172dzj0djc9s665r9kz423wd30d7gxvnf3rswg73ial8k";
      });
    }

    {
      name = "v1.18.nix";
      path = generateK8S "v1.18" (builtins.fetchurl {
        url = "https://github.com/kubernetes/kubernetes/raw/v1.18.0/api/openapi-spec/swagger.json";
        sha256 = "0f3qdn8bfc25a0h8cbdh75mpz1dykbmgymn6qr0rjnisc124fsy1";
      });
    }

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

  generate.istio = pkgs.linkFarm "istio-generated.nix" [{
    name = "latest.nix";
    path = generateIstio;
  }];

  tests = {
    k8s-1_11 = runK8STests "1.11";
    k8s-1_12 = runK8STests "1.12";
    k8s-1_13 = runK8STests "1.13";
    k8s-1_14 = runK8STests "1.14";
    k8s-1_15 = runK8STests "1.15";
    k8s-1_16 = runK8STests "1.16";
    k8s-1_17 = runK8STests "1.17";
    k8s-1_18 = runK8STests "1.18";
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
