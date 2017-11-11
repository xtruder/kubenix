{lib, k8s, ...}:

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
      };

      config = {
        kubernetes.resources.deployments.nginx = mkMerge [
          (k8s.loadJSON ./deployment.json)
          {
            metadata.name = "${name}-nginx";

            spec.template.spec.containers.nginx.ports."80" = {
              containerPort = config.port;
            };

            spec.template.spec.containers.nginx.env.name.valueFrom.secretKeyRef = {
              name = config.kubernetes.resources.configMaps.nginx.metadata.name;
              key = "somekey";
            };
          }
        ];

        kubernetes.resources.configMaps.nginx = mkMerge [
          (k8s.loadJSON ./configMap.json)
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

    kubernetes.resources.services.nginx = k8s.loadJSON ./service.json;

    kubernetes.defaultModuleConfiguration = [{
      kubernetes.defaults.deployments.spec.replicas = 3;
    }];
  };
}
