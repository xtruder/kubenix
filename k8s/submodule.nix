{ config, lib, kubenix, ... }:

with lib;

let
  globalConfig = config;
in {
  imports = [ kubenix.submodules ];

  options = {
    kubernetes.propagateDefaults = mkOption {
      description = "Whether to propagate child defaults to submodules";
      type = types.bool;
      default = true;
    };

    submodules.instances = mkOption {
       type = types.attrsOf (types.submodule ({config, ...}: {
        options = {
          namespace = mkOption {
            description = "Default kubernetes namespace";
            type = types.str;
            default = "default";
          };
        };

        config.config = {
          kubernetes.api.defaults = [{
            default.metadata.namespace = mkDefault config.namespace;
          }];
        };
      }));
    };
  };

  config = {
    submodules.defaults = [{
      default = {
        imports = [ kubenix.k8s ];
        kubernetes.version = mkDefault config.kubernetes.version;
        kubernetes.api.defaults =
          mkIf config.kubernetes.propagateDefaults config.kubernetes.api.defaults;
      };
    } {
      default = ({config, ...}: {
        kubernetes.api.defaults = [{
          default.metadata.labels = {
            "kubenix/module-name" = config.submodule.name;
            "kubenix/module-version" = config.submodule.version;
          };
        }];
      });
    }];

    kubernetes.objects = mkMerge (mapAttrsToList (_: submodule:
      submodule.config.kubernetes.objects
    ) config.submodules.instances);
  };
}
