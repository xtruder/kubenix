# module.nix defines default kubenix module with additional helper options
# and preincluded kubenix module definitions for kubernetes, docker and
# kubenix submodules

{ config, lib, ... }:

with lib;

let
  parentConfig = config;
in {
  imports = [ ./k8s.nix ./docker.nix ./submodules.nix ];

  options = {
    kubenix.release = mkOption {
      description = "Name of the release";
      type = types.str;
      default = "default";
    };

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
        imports = [ ./module.nix ];
        kubernetes.version = mkDefault config.kubernetes.version;
        kubernetes.api.defaults =
          mkIf config.kubernetes.propagateDefaults config.kubernetes.api.defaults;
      };
    } {
      default = ({config, ...}: {
        kubenix.release = parentConfig.kubenix.release;
        kubernetes.api.defaults = [{
          default.metadata.labels = {
            "kubenix/release-name" = config.kubenix.release;
            "kubenix/module-name" = config.submodule.name;
            "kubenix/module-version" = config.submodule.version;
          };
        }];
      });
    }];

    kubernetes.objects = mkMerge (mapAttrsToList (_: submodule:
      submodule.config.kubernetes.objects
    ) config.submodules.instances);

    docker.export = mkMerge (mapAttrsToList (_: submodule:
      submodule.config.docker.export
    ) config.submodules.instances);
  };
}
