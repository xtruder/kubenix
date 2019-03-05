{ name, config, lib, kubenix, images, ... }:

with lib;

let
  cfg = config.submodules.instances.test.config;
  deployment = cfg.kubernetes.api.deployments.nginx;
in {
  imports = [
    kubenix.all
  ];

  test = {
    name = "all";
    description = "Test testing all submodule";
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
      $kube->waitUntilSucceeds("docker load < ${image}");
      $kube->waitUntilSucceeds("kubectl apply -f ${toYAML config.kubernetes.generated}");

      $kube->succeed("kubectl get deployment -n test | grep -i test-nginx");
      $kube->waitUntilSucceeds("kubectl get deployment -n test -o go-template test-nginx --template={{.status.readyReplicas}} | grep 1");
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
