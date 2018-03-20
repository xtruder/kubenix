{lib, k8s, config, ...}:

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

        password = mkSecretOption {
          description = "Nginx simple auth credentials";
          default = null;
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

            spec.template.spec.containers.nginx.env.name =
              mkIf (config.password != null) (secretToEnv config.password);
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

    kubernetes.modules.app-v1 = {
      module = "nginx";
      configuration.password.name = "test2";
      configuration.password.key = "password";

      configuration.kubernetes.resources.customResourceDefinitions.secret-claims = {
        kind = "CustomResourceDefinition";
        apiVersion = "apiextensions.k8s.io/v1beta1";
        metadata.name = "secretclaims.vaultproject.io";
        spec = {
          group = "vaultproject.io";
          version = "v1";
          scope = "Namespaced";
          names = {
            plural = "secretclaims";
            kind = "SecretClaim";
            shortNames = ["scl"];
          };
        };
      };

      configuration.kubernetes.customResources.secret-claims.claim = {
        metadata.name = "test";
      };

    };
    kubernetes.modules.app-v2 = {
      module = "nginx";
      configuration.port = 8080;

      configuration.kubernetes.modules.subsubmodule = {
        module = "nginx";
        configuration.kubernetes.resources.customResourceDefinitions.secret-claims = {
          kind = "CustomResourceDefinition";
          apiVersion = "apiextensions.k8s.io/v1beta1";
          metadata.name = "secretclaims.vaultproject.io";
          spec = {
            group = "vaultproject.io";
            version = "v1";
            scope = "Namespaced";
            names = {
              plural = "secretclaims";
              kind = "SecretClaim";
              shortNames = ["scl"];
            };
          };
        };

        configuration.kubernetes.customResources.secret-claims.claim = {
          metadata.name = "test";
        };
      };
    };

    kubernetes.resources.services.nginx = loadJSON ./service.json;

    kubernetes.defaultModuleConfiguration.all = [{
      config.kubernetes.defaults.deployments.spec.replicas = mkDefault 3;
    }];

    kubernetes.defaultModuleConfiguration.nginx = {config, name, ...}: {
      kubernetes.defaults.deployments.spec.replicas = 4;
    };
  };
}
