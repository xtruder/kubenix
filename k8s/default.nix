{ config, lib, pkgs, ... }:

with lib;

let
  isModule = hasAttr "module" config;

  removeKubenixOptions = filterAttrs (name: attr: name != "kubenix");

  moduleToAttrs = value:
    if isAttrs value
    then mapAttrs (n: v: moduleToAttrs v) (filterAttrs (n: v: !(hasPrefix "_" n) && v != null) value)

    else if isList value
    then map (v: moduleToAttrs v) value

    else value;

  flattenResources = resources: flatten (
    mapAttrsToList (groupName: versions:
      mapAttrsToList (versionName: kinds:
        builtins.trace versionName kinds
      ) versions
    ) resources
  );

  toKubernetesList = resources: {
    kind = "List";
    apiVersion = "v1";
    items = resources;
  };

  apiOptions = { config, ... }: {
    options = {
      definitions = mkOption {
        description = "Attribute set of kubernetes definitions";
      };

      defaults = mkOption {
        description = "Kubernetes defaults";
        type = types.attrsOf (types.coercedTo types.unspecified (value: [value]) (types.listOf types.unspecified));
        default = {};
      };

      resources = mkOption {
        type = types.listOf (types.submodule {
          options = {
            group = mkOption {
              description = "Group name";
              type = types.str;
            };

            version = mkOption {
              description = "Version name";
              type = types.str;
            };

            kind = mkOption {
              description = "kind name";
              type = types.str;
            };

            plural = mkOption {
              description = "Plural name";
              type = types.str;
            };
          };
        });
        default = [];
      };
    };
  };
in {
  imports = [./lib.nix];

  options.kubernetes.version = mkOption {
    description = "Kubernetes version to use";
    type = types.enum ["1.7" "1.8" "1.9" "1.10" "1.11" "1.12" "1.13"];
    default = "1.13";
  };

  options.kubernetes.api = mkOption {
    type = types.submodule {
      imports = [
        (./generated + ''/v'' + config.kubernetes.version + ".nix")
        apiOptions
      ] ++ (map (cr: {config, ...}: {
        options.${cr.group}.${cr.version}.${cr.kind} = mkOption {
          description = cr.description;
          type = types.attrsOf (types.submodule ({name, ...}: {
            options = {
              apiVersion = mkOption {
                description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#resources";
                type = types.nullOr types.str;
              };

              kind = mkOption {
                description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds";
                type = types.nullOr types.str;
              };

              metadata = mkOption {
                description = "Standard object metadata; More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata.";
                type = types.nullOr (types.submodule config.definitions."io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
              };

              spec = mkOption {
                description = "Module spec";
                type = types.submodule cr.module;
                default = {};
              };
            };

            config = mkMerge ([{
              apiVersion = mkOptionDefault "${cr.group}/${cr.version}";
              kind = mkOptionDefault cr.kind;
              metadata.name = mkOptionDefault name;
            }]
              ++ (config.kubernetes.defaults.all or []));
          }));
          default = {};
        };
      }) config.kubernetes.customResources);
    };
    default = {};
  };

  options.kubernetes.customResources = mkOption {
    default = [];
    type = types.listOf (types.submodule ({config, ...}: {
      options = {
        group = mkOption {
          description = "CRD group";
          type = types.str;
        };

        version = mkOption {
          description = "CRD version";
          type = types.str;
        };

        kind = mkOption {
          description = "CRD kind";
          type = types.str;
        };

        plural = mkOption {
          description = "CRD plural name";
          type = types.str;
        };

        description = mkOption {
          description = "CRD description";
          type = types.str;
          default = "";
        };

        module = mkOption {
          description = "CRD module";
          default = types.unspecified;
        };
      };
    }));
  };

  config.kubernetes.api.resources = map (cr: {
    inherit (cr) group version kind plural;
  }) config.kubernetes.customResources;

  options.kubernetes.propagateDefaults = mkOption {
    description = "Whehter to propagate child defaults";
    type = types.bool;
    default = false;
  };

  options.kubernetes.objects = mkOption {
    description = "Attribute set of kubernetes objects";
    type = types.listOf types.attrs;
    apply = unique;
    default = [];
  };

  config.kubernetes.objects = flatten (map (gvk:
    mapAttrsToList (name: resource:
      removeKubenixOptions (moduleToAttrs resource)
    ) config.kubernetes.api.${gvk.group}.${gvk.version}.${gvk.kind}
  ) config.kubernetes.api.resources);

  options.kubernetes.generated = mkOption {
    type = types.package;
    description = "Generated json file";
  };

  config.kubernetes.generated = let
    kubernetesList = toKubernetesList config.kubernetes.objects;

    listHash = builtins.hashString "sha1" (builtins.toJSON kubernetesList);

    hashedList = kubernetesList // {
      labels."kubenix/build" = listHash;
      items = map (resource: recursiveUpdate resource {
        metadata.labels."kubenix/build" = listHash;
      }) kubernetesList.items;
    };
  in pkgs.writeText "resources.json" (builtins.toJSON hashedList);
}
