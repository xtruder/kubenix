{ config, test, kubenix, k8s, ... }:

with k8s;

let
  cfg = config.kubernetes.api.pods.nginx;
in {
  imports = [
    kubenix.k8s
  ];

  test = {
    name = "k8s/simple";
    description = "Simple k8s testing wheter name, apiVersion and kind are preset";
    assertions = [{
      message = "should have apiVersion and kind set";
      assertion = cfg.apiVersion == "v1" && cfg.kind == "Pod";
    } {
      message = "should have name set";
      assertion = cfg.metadata.name == "nginx";
    }];
  };

  kubernetes.api.pods.nginx = {};
}
