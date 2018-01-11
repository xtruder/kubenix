{ config, lib, pkgs, k8s, ... }:

with lib;
with import ./lib.nix { inherit pkgs lib; };

let
  globalConfig = config;

  # A submodule (like typed attribute set). See NixOS manual.
  submodule = opts:
    let
      opts' = toList opts;
      inherit (lib.modules) evalModules;
    in
    mkOptionType rec {
      name = "submodule";
      check = x: isAttrs x || isFunction x;
      merge = loc: defs:
        let
          coerce = def: if isFunction def then def else { config = def; };
          modules = opts' ++ map (def: { _file = def.file; imports = [(coerce def.value)]; }) defs;
        in (evalModules {
          inherit modules;
          args.name = module.name;
          prefix = loc;
        }).config;
      getSubOptions = prefix: (evalModules
        { modules = opts'; inherit prefix;
          # This is a work-around due to the fact that some sub-modules,
          # such as the one included in an attribute set, expects a "args"
          # attribute to be given to the sub-module. As the option
          # evaluation does not have any specific attribute name, we
          # provide a default one for the documentation.
          #
          # This is mandatory as some option declaration might use the
          # "name" attribute given as argument of the submodule and use it
          # as the default of option declarations.
          args.name = "&lt;name&gt;";
        }).options;
      getSubModules = opts';
      substSubModules = m: submodule m;
      functor = (defaultFunctor name) // {
        # Merging of submodules is done as part of mergeOptionDecls, as we have to annotate
        # each submodule with its location.
        payload = [];
        binOp = lhs: rhs: [];
      };
    };

  mkModuleOptions = moduleDefinition: module:
    [
      {
        _file = "${module.name}";
        _module.args.k8s = k8s;
      }
      (import ./kubernetes.nix {
        customResourceDefinitions =
          config.kubernetes.resources.customResourceDefinitions;
      })
      ./modules.nix
      (moduleDefinition.module)
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
          type = submodule {
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
