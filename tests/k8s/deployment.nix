{ config, lib, pkgs, test, kubenix, ... }:

with lib;

let
  cfg = config.kubernetes.api.deployments.nginx;

  nginxImage = let
    nginxPort = "80";
    nginxConf = pkgs.writeText "nginx.conf" ''
      user nginx nginx;
      daemon off;
      error_log /dev/stdout info;
      pid /dev/null;
      events {}
      http {
        access_log /dev/stdout;
        server {
          listen ${nginxPort};
          index index.html;
          location / {
            root ${nginxWebRoot};
          }
        }
      }
    '';
    nginxWebRoot = pkgs.writeTextDir "index.html" ''
      <html><body><h1>Hello from NGINX</h1></body></html>
    '';
  in pkgs.dockerTools.buildLayeredImage {
    name = "xtruder/nginx";
    tag = "latest";
    contents = [pkgs.nginx];
    extraCommands = ''
      mkdir etc
      chmod u+w etc
      echo "nginx:x:1000:1000::/:" > etc/passwd
      echo "nginx:x:1000:nginx" > etc/group
    '';
    config = {
      Cmd = ["nginx" "-c" nginxConf];
      ExposedPorts = {
        "${nginxPort}/tcp" = {};
      };
    };
  };
in {
  imports = [
    kubenix.k8s
  ];

  test = {
    name = "k8s-deployment-simple";
    description = "Simple k8s testing a simple deployment";
    assertions = [{
      message = "should have correct apiVersion and kind set";
      assertion = cfg.apiVersion == "apps/v1" && cfg.kind == "Deployment";
    } {
      message = "should have replicas set";
      assertion = cfg.spec.replicas == 10;
    }];
    check = ''
      $kube->waitUntilSucceeds("docker load < ${nginxImage}");
      $kube->waitUntilSucceeds("kubectl apply -f ${toYAML config.kubernetes.generated}");

      $kube->succeed("kubectl get deployment | grep -i nginx");
      $kube->waitUntilSucceeds("kubectl get deployment -o go-template nginx --template={{.status.readyReplicas}} | grep 10");
      $kube->waitUntilSucceeds("${pkgs.curl}/bin/curl http://nginx.default.svc.cluster.local | grep -i hello");
    '';
  };

  kubernetes.api.deployments.nginx = {
    spec = {
      replicas = 10;
      selector.matchLabels.app = "nginx";
      template.metadata.labels.app = "nginx";
      template.spec = {
        containers.nginx = {
          image = "xtruder/nginx:latest";
          imagePullPolicy = "Never";
        };
      };
    };
  };

  kubernetes.api.services.nginx = {
    spec = {
      ports = [{
        name = "http";
        port = 80;
      }];
      selector.app = "nginx";
    };
  };
}
