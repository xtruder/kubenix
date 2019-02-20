{ config, pkgs, lib, kubenix, ... }:

with lib;

let
  cfg = config.testing;
  parentConfig = config;

  nixosTesting = import <nixpkgs/nixos/lib/testing.nix> {
    inherit pkgs;
    system = "x86_64-linux";
  };

  mkKubernetesBaseTest =
    { name, domain ? "my.zyx", test, machines
    , extraConfiguration ? null }:
    let
      masterName = head (filter (machineName: any (role: role == "master") machines.${machineName}.roles) (attrNames machines));
      master = machines.${masterName};
      extraHosts = ''
        ${master.ip}  etcd.${domain}
        ${master.ip}  api.${domain}
        ${concatMapStringsSep "\n" (machineName: "${machines.${machineName}.ip}  ${machineName}.${domain}") (attrNames machines)}
      '';
      kubectl = with pkgs; runCommand "wrap-kubectl" { buildInputs = [ makeWrapper ]; } ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.kubernetes}/bin/kubectl $out/bin/kubectl --set KUBECONFIG "/etc/kubernetes/cluster-admin.kubeconfig"
      '';
    in nixosTesting.makeTest {
      inherit name;

      nodes = mapAttrs (machineName: machine:
        { config, pkgs, lib, nodes, ... }:
          mkMerge [
            {
              boot.postBootCommands = "rm -fr /var/lib/kubernetes/secrets /tmp/shared/*";
              virtualisation.memorySize = mkDefault 1536;
              virtualisation.diskSize = mkDefault 4096;
              networking = {
                inherit domain extraHosts;
                primaryIPAddress = mkForce machine.ip;

                firewall = {
                  allowedTCPPorts = [
                    10250 # kubelet
                  ];
                  trustedInterfaces = ["docker0"];

                  extraCommands = concatMapStrings  (node: ''
                    iptables -A INPUT -s ${node.config.networking.primaryIPAddress} -j ACCEPT
                  '') (attrValues nodes);
                };
              };
              environment.systemPackages = [ kubectl ];
              services.flannel.iface = "eth1";
              services.kubernetes = {
                easyCerts = true;
                inherit (machine) roles;
                apiserver = {
                  securePort = 443;
                  advertiseAddress = master.ip;
                };
                masterAddress = "${masterName}.${config.networking.domain}";
              };
            }
            (optionalAttrs (any (role: role == "master") machine.roles) {
              networking.firewall.allowedTCPPorts = [
                443 # kubernetes apiserver
              ];
            })
            (optionalAttrs (machine ? "extraConfiguration") (machine.extraConfiguration { inherit config pkgs lib nodes; }))
            (optionalAttrs (extraConfiguration != null) (extraConfiguration { inherit config pkgs lib nodes; }))
          ]
      ) machines;

      testScript = ''
        startAll;

        ${test}
      '';
    };

  mkKubernetesSingleNodeTest = attrs: mkKubernetesBaseTest ({
    machines = {
      kube = {
        roles = ["master" "node"];
        ip = "192.168.1.1";
      };
    };
  } // attrs // {
    name = "kubernetes-${attrs.name}-singlenode";
  });
in {
  options = {
    testing.throwError = mkOption {
      description = "Whether to throw error";
      type = types.bool;
      default = true;
    };

    testing.defaults = mkOption {
      description = "Testing defaults";
      type = types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified);
      example = literalExample ''{config, ...}: {
        kubernetes.version = config.kubernetes.version;
      }'';
      default = [];
    };

    testing.tests = mkOption {
      description = "Attribute set of test cases";
      default = [];
      type = types.listOf (types.coercedTo types.path (module: {inherit module;}) (types.submodule ({config, ...}: let
        modules = [config.module ./test.nix {
          config._module.args.test = config;
        }] ++ cfg.defaults;

        test = (kubenix.evalKubernetesModules {
          check = false;
          inherit modules;
        }).config.test;

        evaled =
          if test.enable
          then builtins.trace "testing ${test.name}" (kubenix.evalKubernetesModules {
            inherit modules;
          })
          else {success = false;};
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
            description = "Wheter test was evaled";
            type = types.bool;
            default =
              if cfg.throwError
              then if evaled.config.test.assertions != [] then true else true
              else (builtins.tryEval evaled.config.test.assertions).success;
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

          script = mkOption {
            description = "Test script";
            type = types.nullOr types.package;
            default = null;
          };
        };

        config = mkMerge [{
          inherit (test) name description enable;
        } (mkIf config.evaled {
          inherit (evaled.config.test) assertions;
          success = all (el: el.assertion) config.assertions;
          script = if evaled.config.test.check != null then mkKubernetesSingleNodeTest {
            name = config.name;
            test = ''
              $kube->waitUntilSucceeds("kubectl get node machine1.my.zyx | grep -w Ready");
              ${evaled.config.test.check}
            '';
          } else null;
        })];
      })));
      apply = tests: filter (test: test.enable) tests;
    };

    testing.success = mkOption {
      description = "Whether testing was a success";
      type = types.bool;
      default = all (test: test.success) cfg.tests;
    };

    testing.result = mkOption {
      description = "Testing result";
      type = types.package;
      default = pkgs.writeText "testing-report.json" (builtins.toJSON {
        success = cfg.success;
        tests = map (test: {
          inherit (test) name description evaled success;
          assertions = moduleToAttrs test.assertions;
          script = test.script;
        }) (filter (test: test.enable) cfg.tests);
      });
    };
  };
}
