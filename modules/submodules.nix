{ config, kubenix, pkgs, lib, ... }:

with lib;
with import ../lib/modules.nix { inherit lib; };

let
  cfg = config.submodules;
  parentConfig = config;

  getDefaults = {name, tags, features}:
    catAttrs "default" (filter (submodule:
      (submodule.name == null || submodule.name == name) &&
      (
        (length submodule.tags == 0) ||
        (length (intersectLists submodule.tags tags)) > 0
      ) &&
      (
        (length submodule.features == 0) ||
        (length (intersectLists submodule.features features)) > 0
      )
    ) config.submodules.defaults);

  specialArgs = cfg.specialArgs // {
    parentConfig = config;
  };

  findSubmodule = {name, version ? null, latest ? true}: let
    matchingSubmodules = filter (el:
      el.definition.name == name &&
      (if version != null then
        if hasPrefix "~" version
        then (builtins.match (removePrefix "~" version) el.definition.version) != null
        else el.definition.version == version
      else true)
    ) cfg.imports;

    versionSortedSubmodules = sort (s1: s2:
      if builtins.compareVersions s1.definition.version s2.definition.version > 0
      then true else false
    ) matchingSubmodules;

    matchingModule =
      if length versionSortedSubmodules == 0
      then throw "No module found ${name}/${if version == null then "latest" else version}"
      else head versionSortedSubmodules;
  in matchingModule;
in {
  imports = [ ./base.nix ];

  options = {
    submodules.specialArgs = mkOption {
      description = "Special args to pass to submodules. These arguments can be used for imports";
      type = types.attrs;
      default = {};
    };

    submodules.defaults = mkOption {
      description = "List of defaults to apply to submodule instances";
      type = types.listOf (types.submodule ({config, ...}: {
        options = {
          name = mkOption {
            description = "Name of the submodule to apply defaults to";
            type = types.nullOr types.str;
            default = null;
          };

          tags = mkOption {
            description = "List of tags to apply defaults to";
            type = types.listOf types.str;
            default = [];
          };

          features = mkOption {
            description = "List of features that submodule has to have to apply defaults";
            type = types.listOf types.str;
            default = [];
          };

          default = mkOption {
            description = "Default to apply to submodule instance";
            type = types.unspecified;
            default = {};
          };
        };
      }));
      default = [];
    };

    submodules.propagate.enable = mkOption {
      description = "Whether to propagate defaults and imports from parent to child";
      type = types.bool;
      default = true;
    };

    submodules.imports = mkOption {
      description = "List of submodule imports";
      type = types.listOf (
        types.coercedTo
          types.path
          (module: {inherit module;})
          (types.submodule ({name, config, ...}: let
            evaledSubmodule' = evalModules {
              inherit specialArgs;
              modules = config.modules ++ [ ./base.nix ];
              check = false;
            };

            evaledSubmodule =
              if (!(elem "submodule" evaledSubmodule'.config._module.features))
              then throw "no submodule defined"
              else evaledSubmodule';
          in {
            options = {
              module = mkOption {
                description = "Module defining submodule";
                type = types.unspecified;
              };

              modules = mkOption {
                description = "List of modules defining submodule";
                type = types.listOf types.unspecified;
                default = [config.module];
              };

              features = mkOption {
                description = "List of features exposed by submodule";
                type = types.listOf types.str;
              };

              definition = mkOption {
                description = "Submodule definition";
                type = types.attrs;
              };
            };

            config = {
              definition = {
                inherit (evaledSubmodule.config.submodule) name description version tags;
              };

              features = evaledSubmodule.config._module.features;
            };
          })
        )
      );
      default = [];
    };

    submodules.instances = mkOption {
      description = "Attribute set of submodule instances";
      default = {};
      type = types.attrsOf (types.submodule ({name, config, options, ...}: let
        # submodule associated with
        submodule = findSubmodule {
          name = config.submodule;
          version = config.version;
        };

        # definition of a submodule
        submoduleDefinition = submodule.definition;

        # submodule defaults
        defaults = getDefaults {
          name = submoduleDefinition.name;
          tags = submoduleDefinition.tags;
          features = submodule.features;
        };
      in {
        options = {
          name = mkOption {
            description = "Submodule instance name";
            type = types.str;
            default = name;
          };

          submodule = mkOption {
            description = "Name of the submodule to use";
            type = types.str;
            default = name;
          };

          version = mkOption {
            description = ''
              Version of submodule to use, if version starts with "~" it is
              threated as regex pattern for example "~1.0.*"
            '';
            type = types.nullOr types.str;
            default = null;
          };

          passthru.enable = mkOption {
            description = "Whether to passthru submodule resources";
            type = types.bool;
            default = true;
          };

          config = mkOption {
            description = "Submodule instance ${config.name} for ${submoduleDefinition.name}:${submoduleDefinition.version} config";
            type = submoduleWithSpecialArgs ({...}: {
              imports = submodule.modules ++ defaults ++ [ ./base.nix ];
              _module.args.pkgs = pkgs;
              _module.args.name = config.name;
              _module.args.submodule = config;
              submodule.args = mkAliasDefinitions options.args;
            }) specialArgs;
            default = {};
          };

          args = mkOption {
            description = "Submodule arguments (alias of config.submodule.args)";
          };
        };
      }));
    };
    default = {};
  };

  config = mkMerge ([
    {
      _module.features = ["submodules"];

      submodules.specialArgs.kubenix = kubenix;

      # passthru kubenix.project to submodules
      submodules.defaults = mkMerge [
        [{
          default = {
            kubenix.project = parentConfig.kubenix.project;
          };
        }]

        (map (propagate: {
          features = propagate.features;
          default = propagate.module;
        }) config._module.propagate)
      ];
    }

    (mkIf cfg.propagate.enable {
      # if propagate is enabled and submodule has submodules included propagage defaults and imports
      submodules.defaults = [{
        features = ["submodules"];
        default = {
          submodules = {
            defaults = cfg.defaults;
            imports = cfg.imports;
          };
        };
      }];
    })
  ];
}
