{ nixosPath, config, pkgs, lib, kubenix, ... }:

with lib;

let
  cfg = config.testing;
  k3s = pkgs.k3s;
  k3sAirgapImages = pkgs.callPackage ./k3s-airgap-images.nix {};
  toJSONFile = content: builtins.toFile "json" (builtins.toJSON content);

  nixosTesting = import "${nixosPath}/lib/testing-python.nix" {
    inherit pkgs;
    system = "x86_64-linux";
  };

  kubernetesBaseConfig = { modulesPath, config, pkgs, lib, nodes, ... }: let
    master = findFirst
      (node: any (role: role == "master") node.config.services.kubernetes.roles)
      (throw "no master node")
      (attrValues nodes);
    extraHosts = ''
      ${master.config.networking.primaryIPAddress}  etcd.${config.networking.domain}
      ${master.config.networking.primaryIPAddress}  api.${config.networking.domain}
      ${concatMapStringsSep "\n"
        (node: let n = node.config.networking; in "${n.primaryIPAddress}  ${n.hostName}.${n.domain}")
        (attrValues nodes)}
    '';
  in {
    imports = [ "${toString modulesPath}/profiles/minimal.nix" ];

    config = mkMerge [{
      boot.postBootCommands = "rm -fr /var/lib/kubernetes/secrets /tmp/shared/*";
      virtualisation.memorySize = mkDefault 2048;
      virtualisation.cores = mkDefault 16;
      virtualisation.diskSize = mkDefault 4096;
      networking = {
        inherit extraHosts;
        domain = "my.xzy";
        nameservers = ["10.0.0.254"];
        firewall = {
          allowedTCPPorts = [
            10250 # kubelet
          ];
          trustedInterfaces = ["docker0" "cni0"];

          extraCommands = concatMapStrings  (node: ''
            iptables -A INPUT -s ${node.config.networking.primaryIPAddress} -j ACCEPT
          '') (attrValues nodes);
        };
      };
      environment.systemPackages = [ pkgs.kubectl ];
      environment.variables.KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
      services.flannel.iface = "eth1";
      services.kubernetes = {
        easyCerts = true;
        apiserver = {
          securePort = 443;
          advertiseAddress = master.config.networking.primaryIPAddress;
        };
        masterAddress = "${master.config.networking.hostName}.${master.config.networking.domain}";
      };

      systemd.extraConfig = "DefaultLimitNOFILE=1048576";
    }
    (mkIf (any (role: role == "master") config.services.kubernetes.roles) {
      networking.firewall.allowedTCPPorts = [
        443 # kubernetes apiserver
      ];
    })];
  };

  mkKubernetesSingleNodeTest = { name, testScript, extraConfiguration ? {} }:
    nixosTesting.makeTest {
      inherit name;

      nodes.kube = { config, pkgs, nodes, ... }: {
        imports = [ kubernetesBaseConfig extraConfiguration ];
        services.kubernetes = {
          roles = ["master" "node"];
          flannel.enable = false;
          kubelet = {
            networkPlugin = "cni";
            cni.config = [{
              name = "mynet";
              type = "bridge";
              bridge = "cni0";
              addIf = true;
              ipMasq = true;
              isGateway = true;
              ipam = {
                type = "host-local";
                subnet = "10.1.0.0/16";
                gateway = "10.1.0.1";
                routes = [{
                  dst = "0.0.0.0/0";
                }];
              };
            }];
          };
        };
        networking.primaryIPAddress = mkForce "192.168.1.1";
      };

      skipLint = true;

      testScript = ''
        start_all()

        kube.wait_until_succeeds("kubectl get node kube.my.xzy | grep -w Ready")

        ${testScript}
      '';
    };

  k3sBaseConfig = { modulesPath, config, pkgs, lib, nodes, ... }: let
    extraHosts = ''
      ${concatMapStringsSep "\n"
        (node: let n = node.config.networking; in "${n.primaryIPAddress}  ${n.hostName}.${n.domain}")
        (attrValues nodes)}
    '';
  in {
    imports = [ "${toString modulesPath}/profiles/minimal.nix" ];

    config = mkMerge [{
      virtualisation.memorySize = mkDefault 2048;
      virtualisation.cores = mkDefault 16;
      virtualisation.diskSize = mkDefault 4096;
      virtualisation.docker.enable = true;
      networking = {
        inherit extraHosts;
        domain = "my.xzy";
        nameservers = ["10.43.0.10"];
        firewall = {
          trustedInterfaces = ["docker0" "cni0"];

          extraCommands = concatMapStrings  (node: ''
            iptables -A INPUT -s ${node.config.networking.primaryIPAddress} -j ACCEPT
          '') (attrValues nodes);
        };
      };
      environment.systemPackages = [ pkgs.kubectl pkgs.docker k3s ];
      environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      systemd.extraConfig = "DefaultLimitNOFILE=1048576";
      systemd.services.seed-docker-images = {
        description = "Copy k3s airgap images, and services.kubernetes.kubelet.seedDockerImages";
        wantedBy = ["k3s.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = [
            "${pkgs.docker}/bin/docker load --input='${k3sAirgapImages}'"
          ] ++ builtins.map 
            (image : "${pkgs.docker}/bin/docker load --input='${image}'") 
            config.services.kubernetes.kubelet.seedDockerImages;
        };
      };
      systemd.services.k3s = {
        description = "Lightweight Kubernetes";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target" "seed-docker-images.service"];
        
        serviceConfig = {
          # setting --service-cidr 10.0.0.0/24 --cluster-dns 10.0.0.254
          # was flakey, removed and hard coding nameservers to default value
          ExecStart = "${k3s}/bin/k3s server --docker";
          Type = "notify";
          KillMode = "process";
          Delegate = "yes";
          LimitNOFILE = "infinity";
          LimitNPROC = "infinity";
          LimitCORE = "infinity";
          TasksMax = "infinity";
          TimeoutStartSec = "0";
          Restart = "always";
          RestartSec = "5s";
        };
      };
    }
    (mkIf (any (role: role == "master") config.services.kubernetes.roles) {
      networking.firewall.allowedTCPPorts = [
        443 # kubernetes apiserver
      ];
    })];
  };

  mkK3sTest = { name, testScript, extraConfiguration ? {} }:
  
    nixosTesting.makeTest {
      inherit name;
      
      nodes.kube = { config, pkgs, nodes, ... }: {
        imports = [ k3sBaseConfig extraConfiguration ];
        networking.primaryIPAddress = mkForce "192.168.1.1";
      };

      testScript = ''
        startAll;

        $kube->waitForUnit('k3s.service');
        $kube->waitUntilSucceeds("kubectl get node kube | grep -w Ready");

        ${testScript}
      '';
    };
  testOptions = { config, ... }: let
    modules = [config.module ./test.nix ./base.nix {
      config = {
        kubenix.project = mkDefault config.name;
        _module.args = {
          test = config;
        } // cfg.args;
      };
    }] ++ cfg.defaults;

    test = (kubenix.evalModules {
      check = false;
      inherit modules;
    }).config.test;

    evaled' = kubenix.evalModules {
      inherit modules;
    };

    evaled =
      if cfg.throwError then evaled'
      else if (builtins.tryEval evaled'.config.test.assertions).success then evaled' else null;
  in {
    options = {
      name = mkOption {
        description = "test name";
        type = types.str;
        internal = true;
      };

      description = mkOption {
        description = "test description";
        type = types.str;
        internal = true;
      };

      enable = mkOption {
        description = "Whether to enable test";
        type = types.bool;
        internal = true;
      };

      module = mkOption {
        description = "Module defining submodule";
        type = types.unspecified;
      };

      evaled = mkOption {
        description = "Test evaulation result";
        type = types.nullOr types.attrs;
        internal = true;
      };

      success = mkOption {
        description = "Whether test was success";
        type = types.bool;
        internal = true;
        default = false;
      };

      assertions = mkOption {
        description = "Test result";
        type = types.unspecified;
        internal = true;
        default = [];
      };

      test = mkOption {
        description = "Test derivation to run";
        type = types.nullOr types.package;
        default = null;
      };

      result = mkOption {
        description = "Test result";
        type = types.package;
      };
    };

    config = mkMerge [{
      inherit evaled;
      inherit (test) name description enable;
      result = pkgs.runCommand "${cfg.name}-${config.name}-test.json" {
        buildInputs = [ pkgs.jshon pkgs.jq ];
      } ''
        jshon -n object \
          -s "${config.name}" -i name \
          -s "${config.description}" -i description \
          -n "${if config.success then "true" else "false"}" -i success \
          ${if config.test == null then "-n null" else "-s '${config.test}'"} -i test > result.json

        jq -s '.[0].assertions = .[1] | .[0]' result.json ${toJSONFile (map (getAttrs ["assertion" "message"]) config.assertions)} > $out
      '';
    } (mkIf (config.evaled != null) {
      inherit (evaled.config.test) assertions;
      success = all (el: el.assertion) config.assertions;
      test =
        if cfg.e2e && evaled.config.test.testScript != null
        then 
          if evaled.config.test.distro == null || 
             evaled.config.test.distro == "nixos" then 
            mkKubernetesSingleNodeTest {
              name = config.name;
              inherit (evaled.config.test) testScript extraConfiguration;
            }
          else if evaled.config.test.distro == "k3s" then
            mkK3sTest {
              name = config.name;
              inherit (evaled.config.test) testScript extraConfiguration;
            }
          else throw "invalid test.distro ${evaled.config.test.distro}"
        else null;
    })];
  };
in {
  options = {
    testing.name = mkOption {
      description = "Testing suite name";
      type = types.str;
      default = "default";
    };

    testing.throwError = mkOption {
      description = "Whether to throw error";
      type = types.bool;
      default = true;
    };

    testing.e2e = mkOption {
      description = "Whether to enable e2e tests";
      type = types.bool;
      default = true;
    };

    testing.defaults = mkOption {
      description = "Testing defaults";
      type = types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified);
      example = literalExample ''{config, ...}: {
        kubernetes.version = config.kubernetes.version;
      }'';
      apply = filter (v: v!=[]);
      default = [];
    };

    testing.tests = mkOption {
      description = "List of test cases";
      default = [];
      type = types.listOf (types.coercedTo types.path (module: {inherit module;}) (types.submodule testOptions));
      apply = tests: filter (test: test.enable) tests;
    };

    testing.args = mkOption {
      description = "Attribute set of extra args passed to tests";
      type = types.attrs;
      default = {};
    };

    testing.testsByName = mkOption {
      description = "Tests by name";
      type = types.attrsOf types.attrs;
      default = listToAttrs (map (test: nameValuePair test.name test) cfg.tests);
    };

    testing.success = mkOption {
      description = "Whether testing was a success";
      type = types.bool;
      default = all (test: test.success) cfg.tests;
    };

    testing.results = mkOption {
      description = "Test results";
      type = types.attrsOf types.package;
      default = mapAttrs (_: t: t.result) cfg.testsByName;
    };

    testing.result = mkOption {
      description = "Testing results";
      type = types.package;
      default = pkgs.runCommand "${cfg.name}-test-results.json" {
        buildInputs = [ pkgs.jq ];
      } ''
        jq -s -r '.' ${concatMapStringsSep " " (t: t.result) cfg.tests} > tests.json
        jq -n \
          --rawfile tests tests.json \
          --argjson success `jq -s -r 'if all(.success) == true then true else false end' ${concatMapStringsSep " " (t: t.result) cfg.tests}` \
          '{"success": $success, "tests": $tests | fromjson }' > $out
      '';
    };
  };
}
