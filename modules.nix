{ config, lib, pkgs, k8s, ... }:

with lib;
with import ./lib.nix { inherit pkgs lib; };

let
  globalConfig = config;

  mkModuleOptions = moduleDefinition: module:
  let
    nameToModule = moduleConfig:
    if isFunction moduleConfig then
      {name, ...}@args:
        (moduleConfig (args // {
          name = module.name;
          moduleDefinition = moduleDefinition;
          module = module;
          k8s = k8s;
        })) // {_file = "module-${module.name}";}
      else {name, ...}: moduleConfig // {_file = "module-${module.name}";};
  in [
      (import ./kubernetes.nix {
        customResourceDefinitions =
          config.kubernetes.resources.customResourceDefinitions;
      })
      ./modules.nix
      (nameToModule moduleDefinition.module)
      {
        config.kubernetes.defaults.all.metadata.namespace = mkDefault module.namespace;
      }
     ] ++ config.kubernetes.defaultModuleConfiguration.all
       ++ (optionals (hasAttr moduleDefinition.name config.kubernetes.defaultModuleConfiguration)
         config.kubernetes.defaultModuleConfiguration.${moduleDefinition.name});

  prefixResources = resources: serviceName:
    mapAttrs (groupName: resources:
      mapAttrs' (name: resource: nameValuePair "${serviceName}-${name}" resource) resources
    ) resources;

  defaultModuleConfigurationOptions = mapAttrs (name: moduleDefinition: mkOption {
    description = "Module default configuration for ${name} module";
    type = types.coercedTo types.attrs (value: [value]) (types.listOf types.attrs);
    default = [];
  }) config.kubernetes.moduleDefinitions;
in {
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

  options.kubernetes.defaultModuleConfiguration = mkOption {
    description = "Module default options";
    type = types.submodule {
      options = defaultModuleConfigurationOptions // {
        all = mkOption {
          description = "Module default configuration for all modules";
          type = types.coercedTo types.attrs (value: [value]) (types.listOf types.attrs);
          default = [];
        };
      };
    };
    default = {};
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

        namespace = mkOption {
          description = "Namespace where to deploy module";
          type = types.str;
          default = "default";
        };

        configuration = mkOption {
          description = "Module configuration";
          type = types.submodule {
            imports = mkModuleOptions globalConfig.kubernetes.moduleDefinitions.${config.module} config;
          };
          default = {};
        };

        module = mkOption {
          description = "Name of the module to use";
          type = types.str;
        };
      };
    }));
  };

  config = {
    kubernetes.resources = mkMerge (
      mapAttrsToList (name: module:
        prefixResources (moduleToAttrs module.configuration.kubernetes.resources) module.name
      ) config.kubernetes.modules
    );

    kubernetes.customResources = mkMerge (
      mapAttrsToList (name: module:
        prefixResources (moduleToAttrs module.configuration.kubernetes.customResources) module.name
      ) config.kubernetes.modules
    );

    kubernetes.defaultModuleConfiguration.all = {
      config.kubernetes.version = mkDefault config.kubernetes.version;
    };
  };
}
