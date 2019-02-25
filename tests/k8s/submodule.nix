{ name, config, lib, kubenix, images, ... }:

with lib;

let
  cfg = config.submodules.instances.test.config;
  deployment = cfg.kubernetes.api.deployments.nginx;
  image = images.nginx;
in {
  imports = [
    kubenix.k8s-submodules
  ];

  test = {
    name = "k8s-submodules";
    description = "Simple k8s submodule test";
    assertions = [{
      message = "Namespace not propagated";
      assertion = deployment.metadata.namespace == "test";
    } {
      message = "Version not propagated";
      assertion = cfg.kubernetes.version == config.kubernetes.version;
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
              image = "${image.imageName}:${image.imageTag}";
              imagePullPolicy = "Never";
            };
          };
        };
      };
    };
  }];

  kubernetes.api.namespaces.test = {};

  submodules.instances.test = {
    submodule = "nginx";
    namespace = "test";
  };
}
