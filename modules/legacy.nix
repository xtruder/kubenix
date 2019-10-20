# support for legacy kubenix

{ options, config, pkgs, lib, kubenix, ... }:

with lib;

let
  parentModule = module;

  mkModuleOptions = moduleDefinition: module:
    let
      # gets file where module is defined by looking into moduleDefinitions
      # option.
      file =
        elemAt options.kubernetes.moduleDefinitions.files (
          (findFirst (i: i > 0) 0
            (imap
              (i: def: if hasAttr module.module def then i else 0)
              options.kubernetes.moduleDefinitions.definitions
            )
          ) - 1
        );

      injectModuleAttrs = module: attrs: (
        if isFunction module then args: (applyIfFunction file module args) // attrs
        else if isAttrs mkOptionDefault.module then module // attrs
        else module
      );
    in [
      {
        _module.args.name = module.name;
        _module.args.module = module;
      }
      ./k8s.nix
      ./legacy.nix
      (injectModuleAttrs moduleDefinition.module {_file = file;})
      {
        config.kubernetes.api.defaults = [{
          default.metadata.namespace = mkOptionDefault module.namespace;
        }];
      }
     ] ++ config.kubernetes.defaultModuleConfiguration.all
       ++ (optionals (hasAttr moduleDefinition.name config.kubernetes.defaultModuleConfiguration)
         config.kubernetes.defaultModuleConfiguration.${moduleDefinition.name});

  # prefix kubernetes objects with ${serviceName}, this magic was removed in new kubenix
  prefixResources = resources: serviceName:  map (resource: resource // {
    metadata = resource.metadata // {
      name = "${serviceName}-${resource.metadata.name}";
    };
  }) resources;

  defaultModuleConfigurationOptions = mapAttrs (name: moduleDefinition: mkOption {
    description = "Module default configuration for ${name} module";
    type = types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified);
    default = [];
  }) config.kubernetes.moduleDefinitions;

  getModuleDefinition = name:
    if hasAttr name config.kubernetes.moduleDefinitions
    then config.kubernetes.moduleDefinitions.${name}
    else throw ''requested kubernetes moduleDefinition with name "${name}" does not exist'';

in {
  imports = [ ./k8s.nix ];

  options.kubernetes.moduleDefinitions = mkOption {
    description = "Legacy kubenix attribute set of module definitions";
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        name = mkOption {
          description = "Module definition name";
          type = types.str;
          default = name;
        };

        prefixResources = mkOption {
          description = "Whether resources should be automatically prefixed with module name";
          type = types.bool;
          default = true;
        };

        assignAsDefaults = mkOption {
          description = "Whether to assign resources as defaults, this is usefull for module that add some functionality";
          type = types.bool;
          default = false;
        };

        module = mkOption {
          description = "Module definition";
        };
      };
    }));
  };

  options.kubernetes.defaultModuleConfiguration = mkOption {
    description = "Legacy kubenix module default options";
    type = types.submodule {
      options = defaultModuleConfigurationOptions // {
        all = mkOption {
          description = "Module default configuration for all modules";
          type = types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified);
          default = [];
        };
      };
    };
    default = {};
  };

  options.kubernetes.modules = mkOption {
    description = "Legacy kubenix attribute set of modules";
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
          default =
            if parentModule != null
            then parentModule.namespace
            else "default";
        };

        labels = mkOption {
          description = "Attribute set of module lables";
          type = types.attrsOf types.str;
          default = {};
        };

        configuration = mkOption {
          description = "Module configuration";
          type = submoduleWithSpecialArgs {
            imports = mkModuleOptions (getModuleDefinition config.module) config;
          } {
            inherit kubenix;
          };
          default = {};
        };

        module = mkOption {
          description = "Name of the module to use";
          type = types.str;
          default = config.name;
        };
      };
    }));
  };

  options.kubernetes.defaults = mkOption {
    type = types.attrsOf (types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified));
    description = "Legacy kubenix kubernetes defaults.";
    default = {};
  };

  # for back compatibility with kubernetes.customResources
  options.kubernetes.customResources = options.kubernetes.resources;

  config = {
    kubernetes.api.defaults = mapAttrsToList (attrName: default: let
      type = head (mapAttrsToList (_: v: v) (filterAttrs (_: type: type.attrName == attrName) config.kubernetes.api.types));
    in {
      default = { imports = default; };
    } // (if (attrName == "all") then {} else {
      resource = type.name;
    })) config.kubernetes.defaults;

    kubernetes.objects = mkMerge (
      mapAttrsToList (name: module: let
        moduleDefinition = getModuleDefinition module.module;
      in
        if moduleDefinition.prefixResources
        then prefixResources (module.configuration.kubernetes.objects) module.name
        else module.configuration.kubernetes.objects
      ) config.kubernetes.modules
    );

    # custom resources are now included in normal resources, so just make an alias
    kubernetes.customResources = mkAliasDefinitions options.kubernetes.resources;

    # create custom types from CRDs was old behavior
    kubernetes.createCustomTypesFromCRDs = true;

    kubernetes.defaultModuleConfiguration.all = {
      _file = head options.kubernetes.defaultModuleConfiguration.files;
      config.kubernetes.version = mkDefault config.kubernetes.version;
      config.kubernetes.moduleDefinitions = config.kubernetes.moduleDefinitions;
    };
  };
}
