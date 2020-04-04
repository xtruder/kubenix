# support for legacy kubenix

{ options, config, pkgs, lib, kubenix, ... }:

with lib;

let
  parentModule = module;
  globalConfig = config;

  mkOptionDefault = mkOverride 1001;

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
        config.kubernetes.namespace = mkOptionDefault module.namespace;
        config.kubenix.project = mkOptionDefault config.kubenix.project;
      }
     ] ++ config.kubernetes.defaultModuleConfiguration.all
       ++ (optionals (hasAttr moduleDefinition.name config.kubernetes.defaultModuleConfiguration)
         config.kubernetes.defaultModuleConfiguration.${moduleDefinition.name});

  # prefix kubernetes objects with ${serviceName}, this magic was removed in new kubenix
  prefixResources = resources: serviceName:
    mapAttrs' (name: resource: nameValuePair "${serviceName}-${name}" resource) resources;

  # TODO: rewrite using mkOptionType
  defaultModuleConfigurationOptions = mapAttrs (name: moduleDefinition: mkOption {
    description = "Module default configuration for ${name} module";
    type = types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified);
    default = [];
    apply = filter (v: v!=[]);
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
          apply = filter (v: v != []);
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
          default = globalConfig.kubernetes.namespace;
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
    type = types.attrsOf (types.coercedTo types.attrs (value: [value]) (types.listOf types.attrs));
    description = "Legacy kubenix kubernetes defaults.";
    default = {};
  };

  # for back compatibility with kubernetes.customResources
  options.kubernetes.customResources = options.kubernetes.resources;

  config = {
    kubernetes = mkMerge [{
      api.defaults = mapAttrsToList (attrName: default: let
        type = head (mapAttrsToList (_: v: v) (filterAttrs (_: type: type.attrName == attrName) config.kubernetes.api.types));
      in {
        default = { imports = default; };
      } // (if (attrName == "all") then {} else {
        resource = type.name;
      })) config.kubernetes.defaults;

      resources = mkMerge (
        mapAttrsToList (name: module:
          mapAttrs' (_: type: let
            moduleDefinition = getModuleDefinition module.module;

            moduleResources = module.configuration.kubernetes.api.resources.${type.attrName} or {};

            moduleConfig =
              if moduleDefinition.prefixResources && type.kind != "CustomResourceDefinition"
              then prefixResources (moduleToAttrs moduleResources) name
              else moduleToAttrs moduleResources;
          in nameValuePair type.attrName
            (if moduleDefinition.assignAsDefaults
            then mkAllDefault moduleConfig 1000
            else moduleConfig)
          ) module.configuration.kubernetes.api.types
        ) config.kubernetes.modules
      );

      # custom types created from customResourceDefinitions
      customTypes =
        mapAttrsToList (name: crd: {
          group = crd.spec.group;
          version = crd.spec.version;
          kind = crd.spec.names.kind;
          name = crd.spec.names.plural;
          attrName = mkOptionDefault name;
        }) (config.kubernetes.resources.customResourceDefinitions or {});

      defaultModuleConfiguration.all = {
        _file = head options.kubernetes.defaultModuleConfiguration.files;
        config.kubernetes.version = mkDefault config.kubernetes.version;
        config.kubernetes.moduleDefinitions = config.kubernetes.moduleDefinitions;
      };
    } {
      resources = mkAliasDefinitions options.kubernetes.customResources;
    }];
  };
}
