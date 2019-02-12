{ config, test, kubenix, ... }:

let
  cfg = config.kubernetes.api.Deployment.nginx;
in {
  imports = [
    kubenix.k8s
  ];

  test = {
    name = "k8s/deployment/simple";
    description = "Simple k8s testing a simple deployment";
    assertions = [{
      message = "should have correct apiVersion and kind set";
      assertion = cfg.apiVersion == "apps/v1" && cfg.kind == "Deployment";
    } {
      message = "should have replicas set";
      assertion = cfg.spec.replicas == 10;
    }];
  };

  kubernetes.api.Deployment.nginx = {
    spec = {
      replicas = 10;
      selector.matchLabels.app = "nginx";
      template.metadata.labels.app = "nginx";
      template.spec = {
        containers.nginx = {
          image = "nginx";
        };
      };
    };
  };
}
