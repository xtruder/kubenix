{ config, lib, pkgs, kubenix, k8s, submodule, ... }:

with lib;

let
  name = submodule.name;
in {
  imports = [
    kubenix.k8s
  ];

  options.args = {
    replicas = mkOption {
      type = types.int;
      description = "Number of nginx replicas to run";
      default = 1;
    };

    simpleAuth = k8s.mkSecretOption {
      description = "Simple auth";
      default = {
        key = "name";
        name = "value";
      };
    };

    image = mkOption {
      description = "Image";
      type = types.str;
      default = "nginx";
    };
  };

  config = {
    submodule = {
      name = "nginx";
      version = "1.0.0";
      description = "Nginx module";
      passthru = {
        kubernetes.objects = config.kubernetes.objects;
      };
    };

    kubernetes.api.Deployment.nginx = {
      metadata = {
        name = name;
        labels = {
          module = config.submodule.name;
        };
      };

      spec = {
        replicas = config.args.replicas;
        selector.matchLabels.app = "nginx";
        template.metadata.labels.app = "nginx";
        template.spec = {
          containers.nginx = {
            image = config.args.image;
            env = {
              SIMPLE_AUTH = k8s.secretToEnv config.args.simpleAuth;
            };
          };
        };
      };
    };
  };
}
