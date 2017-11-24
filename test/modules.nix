{lib, k8s, ...}:

with k8s;
with lib;

{
  config = {
    kubernetes.moduleDefinitions.nginx.module = {name, config, ...}: {
      options = {
        port = mkOption {
          description = "Port for nginx to listen on";
          type = types.int;
          default = 80;
        };

        password = mkValueOrSecretOption {
          description = "Nginx simple auth credentials";
          default.secret = "test";
        };
      };

      config = {
        kubernetes.resources.deployments.nginx = mkMerge [
          (loadJSON ./deployment.json)
          {
            metadata.name = "${name}-nginx";

            spec.template.spec.containers.nginx.ports."80" = {
              containerPort = config.port;
            };

            spec.template.spec.containers.nginx.env.name = config.password;
          }
        ];

        kubernetes.resources.configMaps.nginx = mkMerge [
          (loadJSON ./configMap.json)
          {
            metadata.name = mkForce "${name}-nginx";
          }
        ];
      };
    };

    kubernetes.modules.app-v1.module = "nginx";
    kubernetes.modules.app-v2 = {
      module = "nginx";
      configuration.port = 8080;
    };

    kubernetes.resources.services.nginx = loadJSON ./service.json;

    kubernetes.defaultModuleConfiguration = [{
      kubernetes.defaults.deployments.spec.replicas = 3;
    }];

    kubernetes.defaults.all.metadata.namespace = "test";
  };
}
