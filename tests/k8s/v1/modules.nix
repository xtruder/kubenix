{ config, lib, kubenix, pkgs, k8sVersion, ... }: {

  imports = with kubenix.modules; [ test k8s v1.modules ];

  test = {
    name = "k8s-v1-modules";
    description = "Simple test tesing CRD";
    assertions = [];
  };

  kubernetes.version = k8sVersion;

  kubernetes.moduleDefinitions.app.module = { config, k8s, ... }: {
    kubernetes.resources.deployments.app = {
      spec = {
        replicas = 2;
        selector = {
          matchLabels.app = "app";
        };
        template.spec = {
          containers.app = {
            image = "hello-world";
          };
        };
      };
    };
  };

  kubernetes.modules.myapp = {
    module = "app";
    namespace = "test";
  };
}
