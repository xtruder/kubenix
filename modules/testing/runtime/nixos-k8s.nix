# nixos-k8s implements nixos kubernetes testing runtime

{ nixosPath, config, pkgs, lib, kubenix, ... }:

let
  testConfig = config.evaled.config;

  nixosTesting = import "${nixosPath}/lib/testing.nix" {
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

    config = mkMerge [
      # base configuration for master and nodes
      {
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
          seedDockerImages = mkIf (elem "docker" testConfig._m.features) testConfig.docker.export;
        };

        systemd.extraConfig = "DefaultLimitNOFILE=1048576";
      }

      # configuration only applied on master nodes
      (mkIf (any (role: role == "master") config.services.kubernetes.roles) {
        networking.firewall.allowedTCPPorts = [
          443 # kubernetes apiserver
        ];
      })
    ];
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

      testScript = ''
        startAll;

        $kube->waitUntilSucceeds("kubectl get node kube.my.xzy | grep -w Ready");

        ${testScript}
      '';
    };

in {
  options = {
    runtime.nixos-k8s = {
      driver = mkOption {
        description = "Test driver";
        type = types.package;
        internal = true;
      };
    };

    runtime.nixos-k8s.driver = mkKubernetesSingleNodeTest {
      inherit (config) name testScript;
    };
  };
}
