{ config, kubenix, pkgs, lib, ... }:

with lib;

let
  cfg = config.submodules;

  submoduleWithSpecialArgs = opts: specialArgs:
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
          inherit modules specialArgs;
          prefix = loc;
        }).config;
      getSubOptions = prefix: (evalModules
        { modules = opts'; inherit prefix specialArgs;
          # This is a work-around due to the fact that some sub-modules,
          # such as the one included in an attribute set, expects a "args"
          # attribute to be given to the sub-module. As the option
          # evaluation does not have any specific attribute name, we
          # provide a default one for the documentation.
          #
          # This is mandatory as some option declaration might use the
          # "name" attribute given as argument of the submodule and use it
          # as the default of option declarations.
          #
          # Using lookalike unicode single angle quotation marks because
          # of the docbook transformation the options receive. In all uses
          # &gt; and &lt; wouldn't be encoded correctly so the encoded values
          # would be used, and use of `<` and `>` would break the XML document.
          # It shouldn't cause an issue since this is cosmetic for the manual.
          args.name = "‹name›";
        }).options;
      getSubModules = opts';
      substSubModules = m: submoduleWithSpecialArgs m specialArgs;
      functor = (defaultFunctor name) // {
        # Merging of submodules is done as part of mergeOptionDecls, as we have to annotate
        # each submodule with its location.
        payload = [];
        binOp = lhs: rhs: [];
      };
    };

  submoduleDefinitionOptions = {
    options = {
      name = mkOption {
        description = "Module name";
        type = types.str;
      };

      description = mkOption {
        description = "Module description";
        type = types.str;
        default = "";
      };

      version = mkOption {
        description = "Module version";
        type = types.str;
        default = null;
      };

      passthru = mkOption {
        description = "Submodule passthru";
        type = types.coercedTo types.attrs (value: [value]) (types.listOf types.attrs);
        default = [];
      };
    };
  };

  submoduleOptions = {
    options.submodule = mkOption {
      description = "Submodule options";
      type = types.submodule submoduleDefinitionOptions;
      default = {};
    };
  };

  specialArgs = cfg.specialArgs // {
    parentConfig = config;
  };

  findModule = {name, version ? null, latest ? true}: let
    matchingSubmodules = filter (el:
      el.definition.name == name &&
      (if version != null then el.definition.version == version else true)
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
  options = {
    submodules.specialArgs = mkOption {
      description = "Special args to pass to submodules. These arguments can be used for imports";
      type = types.attrs;
      default = {};
    };

    submodules.defaults = mkOption {
      description = "Submodule defaults";
      type = types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified);
      example = literalExample ''{config, ...}: {
        kubernetes.version = config.kubernetes.version;
      }'';
      default = [];
    };

    submodules.propagateDefaults = mkOption {
      description = "Whether to propagate defaults to submodules";
      type = types.bool;
      default = true;
    };

    submodules.propagate = mkOption {
      description = "Whether to propagate defaults and imports to submodule's submodules";
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
            submoduleDefinition = (evalModules {
              inherit specialArgs;
              modules = config.modules ++ [submoduleOptions];
              check = false;
            }).config.submodule;
          in {
            options = {
              module = mkOption {
                description = "Module defining submodule";
              };

              modules = mkOption {
                description = "List of modules defining submodule";
                type = types.listOf types.unspecified;
                default = [config.module];
              };

              definition = mkOption {
                type = types.submodule submoduleDefinitionOptions;
                default = submoduleDefinition;
              };
            };
          })
        )
      );
      default = [];
    };

    submodules.instances = mkOption {
      description = "Attribute set of submodule instances";
      type = types.attrsOf (types.submodule ({name, config, ...}: let
        submodule = findModule {
          name = config.submodule;
          version = config.version;
        };

        submoduleDefinition = submodule.definition;
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
            description = "Version of submodule to use";
            type = types.nullOr types.str;
            default = null;
          };

          config = mkOption {
            description = "Submodule instance ${config.name} for ${submoduleDefinition.name}:${submoduleDefinition.version} config";
            type =  submoduleWithSpecialArgs ({...}: {
              imports = submodule.modules ++ cfg.defaults ++ [submoduleOptions ./submodules.nix];
              _module.args.name = config.name;
            }) specialArgs;
            default = {};
          };
        };
      }));
    };
    default = {};
  };

  config = {
    submodules.specialArgs.kubenix = kubenix;
    submodules.defaults = mkIf cfg.propagate {
      submodules.defaults = cfg.defaults;
      submodules.imports = cfg.imports;
    };
  };
}
