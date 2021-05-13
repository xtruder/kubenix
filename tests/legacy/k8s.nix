{ config, lib, kubenix, pkgs, ... }:

with lib;
let
  cfg = config.kubernetes.api.resources.deployments.app;
in
{
  imports = with kubenix.modules; [ test k8s legacy ];

  test = {
    name = "legacy-k8s";
    description = "Simple test kubenix legacy kubernetes support";
    assertions = [{
      message = "should have correct resource options set";
      assertion =
        cfg.kind == "Deployment" &&
        cfg.metadata.name == "app";
    }
      {
        message = "should have correct defaults set";
        assertion =
          cfg.metadata.namespace == "test" &&
          cfg.metadata.labels.label1 == "value1" &&
          cfg.metadata.labels.label2 == "value2";
      }];
  };

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

  kubernetes.resources.configMaps.app = {
    data."my-conf.json" = builtins.toJSON { };
  };

  kubernetes.defaults = {
    all = [{
      metadata.namespace = "test";
      metadata.labels.label1 = "value1";
    }];

    deployments = [{
      metadata.labels.label2 = "value2";
    }];
  };
}
