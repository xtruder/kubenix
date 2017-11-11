{ config, lib, pkgs, k8s, ... }:

with lib;
with import ./lib.nix { inherit pkgs lib; };

let
  globalConfig = config;

  evalK8SModule = {module, name, configuration}: evalModules {
    modules = [
      ./kubernetes.nix ./modules.nix module configuration
    ] ++ config.kubernetes.defaultModuleConfiguration;
    args = {
      inherit pkgs k8s name;
    };
  };

  prefixResources = resources: serviceName:
    mapAttrs (groupName: resources:
      mapAttrs' (name: resource: nameValuePair "${serviceName}-${name}" resource) resources
    ) resources;
in {
  options.kubernetes.defaultModuleConfiguration = mkOption {
    description = "Default configuration for kubernetes modules";
    type = types.listOf types.attrs;
    default = {};
  };

  options.kubernetes.moduleDefinitions = mkOption {
    description = "Attribute set of module definitions";
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        name = mkOption {
          description = "Module definition name";
          type = types.str;
          default = name;
        };

        module = mkOption {
          description = "Module definition";
        };
      };
    }));
  };

  options.kubernetes.modules = mkOption {
    description = "Attribute set of module definitions";
    default = {};
    type = types.attrsOf (types.submodule ({config, name, ...}: {
      options = {
        name = mkOption {
          description = "Module name";
          type = types.str;
          default = name;
        };

        configuration = mkOption {
          description = "Module configuration";
          type = types.attrs;
          default = {};
        };

        module = mkOption {
          description = "Name of the module to use";
          type = types.str;
        };

        evaledModule = mkOption {
          description = "Evaluated config";
          internal = true;
        };
      };

      config = {
        evaledModule = (evalK8SModule {
          module = globalConfig.kubernetes.moduleDefinitions.${config.module}.module;
          inherit (config) name configuration;
        });
      };
    }));
  };

  config = {
    kubernetes.resources = mkMerge (
      mapAttrsToList (name: module:
        prefixResources (moduleToAttrs module.evaledModule.config.kubernetes.resources) module.name
      ) config.kubernetes.modules
    );

    kubernetes.defaultModuleConfiguration = [{
      config.kubernetes.version = mkDefault config.kubernetes.version;
    }];
  };
}
