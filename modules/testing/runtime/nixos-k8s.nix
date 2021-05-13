# nixos-k8s implements nixos kubernetes testing runtime

{ nixosPath
, config
, pkgs
, lib
, system ? "x86_64-linux"
, ...
}:

with lib;

let
  testing = config.testing;
  kubeconfig = "/etc/${config.services.kubernetes.pki.etcClusterAdminKubeconfig}";

  # how we differ from the standard configuration of mkKubernetesBaseTest
  extraConfiguration = { config, pkgs, lib, nodes, ... }: {
    virtualisation.memorySize = mkDefault 2048;
    networking = {
      nameservers = [ "10.0.0.254" ];
      firewall = {
        trustedInterfaces = [ "docker0" "cni0" ];
      };
    };
    services.kubernetes = {
      seedDockerImages = mkIf (elem "docker" config._m.features) config.docker.export;
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
      systemd.extraConfig = "DefaultLimitNOFILE=1048576";
      systemd.services.copy-certs = {
        description = "Share k8s certificates with host";
        script = "cp -rf /var/lib/kubernetes/secrets /tmp/xchg/";
        after = [ "kubernetes.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
  };

  script = ''
    machine1.succeed("${testing.testScript} --kube-config=${kubeconfig}")
  '';

  test =
    with import "${nixosPath}/tests/kubernetes/base.nix" { inherit pkgs system; };
    mkKubernetesSingleNodeTest {
      inherit extraConfiguration;
      inherit (config) name;
      test = script;
    };


in
{
  options = {
    runtime.nixos-k8s = {
      driver = mkOption {
        description = "Test driver";
        type = types.package;
        internal = true;
      };
    };
  };

  runtime.nixos-k8s.driver = test.driver;
}
