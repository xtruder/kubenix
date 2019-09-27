{ config, lib, pkgs, kubenix, images, k8sVersion, ... }:

with lib;

let
  cfg = config.kubernetes.api.resources.deployments.nginx;
  image = images.nginx;
in {
  imports = [ kubenix.modules.test kubenix.modules.k8s kubenix.modules.docker ];

  test = {
    name = "k8s-deployment";
    description = "Simple k8s testing a simple deployment";
    assertions = [{
      message = "should have correct apiVersion and kind set";
      assertion =
        if ((builtins.compareVersions config.kubernetes.version "1.7") <= 0)
        then cfg.apiVersion == "apps/v1beta1"
        else if ((builtins.compareVersions config.kubernetes.version "1.8") <= 0)
        then cfg.apiVersion == "apps/v1beta2"
        else cfg.apiVersion == "apps/v1";
    } {
      message = "should have corrent kind set";
      assertion = cfg.kind == "Deployment";
    } {
      message = "should have replicas set";
      assertion = cfg.spec.replicas == 10;
    }];
    extraConfiguration = {
      environment.systemPackages = [ pkgs.curl ];
      services.kubernetes.kubelet.seedDockerImages = config.docker.export;
    };
    testScript = ''
      $kube->waitUntilSucceeds("kubectl apply -f ${toYAML config.kubernetes.generated}");

      $kube->succeed("kubectl get deployment | grep -i nginx");
      $kube->waitUntilSucceeds("kubectl get deployment -o go-template nginx --template={{.status.readyReplicas}} | grep 10");
      $kube->waitUntilSucceeds("curl http://nginx.default.svc.cluster.local | grep -i hello");
    '';
  };

  docker.images.nginx.image = image;

  kubernetes.version = k8sVersion;

  kubernetes.resources.deployments.nginx = {
    spec = {
      replicas = 10;
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

  kubernetes.resources.services.nginx = {
    spec = {
      ports = [{
        name = "http";
        port = 80;
      }];
      selector.app = "nginx";
    };
  };
}
