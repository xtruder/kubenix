{ config, lib, kubenix, pkgs, k8sVersion, ... }:

with lib;

{

  imports = with kubenix.modules; [ test k8s legacy ];

  test = {
    name = "k8s-legacy";
    description = "Simple test tesing kubenix legacy support";
    assertions = [];
  };

  kubernetes.version = k8sVersion;

  kubernetes.moduleDefinitions.app.module = { config, k8s, ... }: {
    options = {
      replicas = mkOption {
        description = "Number of replicas to run";
        type = types.int;
        default = 2;
      };
    };

    config.kubernetes.defaults = {
      all = [{
        metadata.labels.default = "value";
      }];

      deployments = [{
        metadata.labels.default2 = "value2";
      } {
        metadata.labels.default3 = "value3";
      }];
    };

    config.kubernetes.resources.deployments.app = {
      spec = {
        replicas = config.replicas;
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
    configuration.replicas = 3;
  };
}
