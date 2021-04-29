{ name, config, lib, kubenix, images, ... }:

with lib;

let
  cfg = config.submodules.instances.test.config;
  deployment = cfg.kubernetes.api.deployments.nginx;
in {
  imports = [ kubenix.modules.test kubenix.module ];

  test = {
    name = "module";
    description = "Test testing kubenix module";
    assertions = [{
      message = "Namespace not propagated";
      assertion = deployment.metadata.namespace == "test";
    } {
      message = "Version not propagated";
      assertion = cfg.kubernetes.version == config.kubernetes.version;
    } {
      message = "docker image should be added to exported images";
      assertion = (head config.docker.export) == images.nginx;
    }];
    testScript = ''
      kube.wait_until_succeeds("docker load < ${images.nginx}")
      kube.wait_until_succeeds("kubectl apply -f ${config.kubernetes.result}")

      kube.succeed("kubectl get deployment -n test | grep -i test-nginx")
      kube.wait_until_succeeds("kubectl get deployment -n test -o go-template test-nginx --template={{.status.readyReplicas}} | grep 1")
    '';
  };

  submodules.imports = [{
    module = {name, config, ...}: {
      submodule.name = "nginx";
      kubernetes.api.deployments.nginx = {
        metadata = {
          name = "${name}-nginx";
          labels.app = name;
        };
        spec = {
          replicas = 1;
          selector.matchLabels.app = "nginx";
          template.metadata.labels.app = "nginx";
          template.spec = {
            containers.nginx = {
              image = config.docker.images.nginx.path;
              imagePullPolicy = "Never";
            };
          };
        };
      };

      docker.images.nginx.image = images.nginx;
    };
  }];

  kubernetes.api.namespaces.test = {};

  submodules.instances.test = {
    submodule = "nginx";
    namespace = "test";
  };
}
