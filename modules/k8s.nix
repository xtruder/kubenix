# K8S module defines kubernetes definitions for kubenix

{ config, lib, pkgs, k8s, ... }:

with lib;

let
  cfg = config.kubernetes;

  getDefaults = resource: group: version: kind:
    catAttrs "default" (filter (default:
      (resource == null || default.resource == null || default.resource == resource) &&
      (default.group == null || default.group == group) &&
      (default.version == null || default.version == version) &&
      (default.kind == null || default.kind == kind)
    ) cfg.api.defaults);

  moduleToAttrs = value:
    if isAttrs value
    then mapAttrs (n: v: moduleToAttrs v) (filterAttrs (n: v: v != null && !(hasPrefix "_" n)) value)

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

  apiOptions = { config, ... }: {
    options = {
      definitions = mkOption {
        description = "Attribute set of kubernetes definitions";
      };

      defaults = mkOption {
        description = "Kubernetes defaults to apply to resources";
        type = types.listOf (types.submodule ({config, ...}: {
          options = {
            resource = mkOption {
              description = "Resource to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            group = mkOption {
              description = "Group to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            version = mkOption {
              description = "Version to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            kind = mkOption {
              description = "Kind to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            propagate = mkOption {
              description = "Whether to propagate default";
              type = types.bool;
              default = false;
            };

            default = mkOption {
              description = "Default to apply";
              type = types.unspecified;
              default = {};
            };
          };
        }));
        default = [];
      };

      resources = mkOption {
        type = types.listOf (types.submodule {
          options = {
            group = mkOption {
              description = "Resoruce group";
              type = types.str;
            };

            version = mkOption {
              description = "Resoruce version";
              type = types.str;
            };

            kind = mkOption {
              description = "Resource kind";
              type = types.str;
            };

            resource = mkOption {
              description = "Resource name";
              type = types.str;
            };
          };
        });
        default = [];
      };
    };
  };

  indexOf = lst: value:
    head (filter (v: v != -1) (imap0 (i: v: if v == value then i else -1) lst));

  customResourceOptions = map (cr: {config, ...}: let
    module = { name, ... }: {
      imports = getDefaults cr.resource cr.group cr.version cr.kind;
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

      config = {
        apiVersion = mkOptionDefault "${cr.group}/${cr.version}";
        kind = mkOptionDefault cr.kind;
        metadata.name = mkOptionDefault name;
      };
    };
  in if cr.alias != null then {
    options.${cr.group}.${cr.version}.${cr.kind} = mkOption {
      description = cr.description;
      type = types.attrsOf (types.submodule module);
      default = {};
    };

    options.${cr.alias} = mkOption {
      description = cr.description;
      type = types.attrsOf (types.submodule module);
      default = {};
    };

    config.${cr.group}.${cr.version}.${cr.kind} = config.${cr.alias};
  } else {
    options.${cr.group}.${cr.version}.${cr.kind} = mkOption {
      description = cr.description;
      type = types.attrsOf (types.submodule module);
      default = {};
    };
  }) cfg.customResources;
in {
  imports = [ ./base.nix ./submodules.nix ];

  options.kubernetes = {
    version = mkOption {
      description = "Kubernetes version to use";
      type = types.enum ["1.7" "1.8" "1.9" "1.10" "1.11" "1.12" "1.13"];
      default = "1.13";
    };

    namespace = mkOption {
      description = "Default namespace where to deploy kubernetes resources";
      type = types.str;
      default = "default";
    };

    resourceOrder = mkOption {
      description = "Preffered resource order";
      type = types.listOf types.str;
      default = [
        "CustomResourceDefinition"
        "Namespace"
      ];
    };

    api = mkOption {
      type = types.submodule {
        imports = [
          (./generated + ''/v'' + cfg.version + ".nix")
          apiOptions
        ] ++ customResourceOptions;
      };
      default = {};
    };

    customResources = mkOption {
      default = [];
      description = "List of custom resource definitions to make API for";
      type = types.listOf (types.submodule ({config, ...}: {
        options = {
          group = mkOption {
            description = "Custom resource definition group";
            type = types.str;
          };

          version = mkOption {
            description = "Custom resource definition version";
            type = types.str;
          };

          kind = mkOption {
            description = "Custom resource definition kind";
            type = types.str;
          };

          resource = mkOption {
            description = "Custom resource definition resource name";
            type = types.nullOr types.str;
            default = null;
          };

          description = mkOption {
            description = "Custom resource definition description";
            type = types.str;
            default = "";
          };

          module = mkOption {
            description = "Custom resource definition module";
            default = types.unspecified;
          };

          alias = mkOption {
            description = "Alias to create for API";
            type = types.nullOr types.str;
            default = null;
          };
        };
      }));
    };

    objects = mkOption {
      description = "List of generated kubernetes objects";
      type = types.listOf types.attrs;
      apply = items: sort (r1: r2:
        if elem r1.kind cfg.resourceOrder && elem r2.kind cfg.resourceOrder
        then indexOf cfg.resourceOrder r1.kind < indexOf cfg.resourceOrder r2.kind
        else if elem r1.kind cfg.resourceOrder then true else false
      ) (unique items);
      default = [];
    };

    generated = mkOption {
      description = "Generated kubernetes list object";
      type = types.attrs;
    };
  };

  config = {
    # expose k8s helper methods as module argument
    _module.args.k8s = import ../lib/k8s.nix { inherit lib; };

    _module.features = [ "k8s" ];

    kubernetes.api.resources = map (cr: {
      inherit (cr) group version kind resource;
    }) cfg.customResources;

    kubernetes.objects = mkMerge [
      # gvk resources
      (flatten (map (gvk:
        mapAttrsToList (name: resource:
          moduleToAttrs resource
        ) cfg.api.${gvk.group}.${gvk.version}.${gvk.kind}
      ) cfg.api.resources))

      (flatten (map (gvk:
        mapAttrsToList (name: resource:
          moduleToAttrs resource
        ) cfg.api.${gvk.resource}
      ) cfg.api.resources))

      # passthru of child kubernetes objects if passthru is enabled on submodule
      # and submodule has k8s module loaded
      (flatten (mapAttrsToList (_: submodule:
        optionals
          (submodule.passthru.enable && (elem "k8s" submodule.config._module.features))
          submodule.config.kubernetes.objects
      ) config.submodules.instances))
    ];

    kubernetes.generated = k8s.mkHashedList {
      items = config.kubernetes.objects;
      labels."kubenix/project-name" = config.kubenix.project;
    };

    kubernetes.api.defaults = [{
      default = {
        metadata.namespace = mkDefault config.kubernetes.namespace;
        metadata.labels = mkMerge [
          {
            "kubenix/project-name" = config.kubenix.project;
          }

          # if we are inside submodule, define additional labels
          (mkIf (elem "submodule" config._module.features) {
            "kubenix/module-name" = config.submodule.name;
            "kubenix/module-version" = config.submodule.version;
          })
        ];
      };
    }];

    submodules.defaults = [{
      features = [ "k8s" ];
      default = { config, name, ... }: {
        # propagate kubernetes version and namespace
        kubernetes.version = mkDefault cfg.version;
        kubernetes.namespace = mkDefault cfg.namespace;

        # propagate defaults if default propagation is enabled
        kubernetes.api.defaults = filter (default: default.propagate) cfg.api.defaults;
      };
    }];
  };
}
