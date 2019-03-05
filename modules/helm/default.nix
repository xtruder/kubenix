{ config, lib, pkgs, kubenix, ... }:

with lib;

let
  cfg = config.kubernetes.helm;

  globalConfig = config;

  recursiveAttrs = mkOptionType {
    name = "recursive-attrs";
    description = "recursive attribute set";
    check = isAttrs;
    merge = loc: foldl' (res: def: recursiveUpdate res def.value) {};
  };

  parseApiVersion = apiVersion: let
    splitted = splitString "/" apiVersion;
  in {
    group = if length splitted == 1 then "core" else head splitted;
    version = last splitted;
  };

  chart2json = pkgs.callPackage ./chart2json.nix {  };
  fetchhelm = pkgs.callPackage ./fetchhelm.nix {  };

in {
  imports = [
    kubenix.k8s
  ];

  options.kubernetes.helm = {
    instances = mkOption {
      description = "Attribute set of helm instances";
      type = types.attrsOf (types.submodule ({ config, name, ... }: {
        options = {
          name = mkOption {
            description = "Helm release name";
            type = types.str;
            default = name;
          };

          chart = mkOption {
            description = "Helm chart to use";
            type = types.package;
          };

          namespace = mkOption {
            description = "Namespace to install helm chart to";
            type = types.nullOr types.str;
            default = null;
          };

          values = mkOption {
            description = "Values to pass to chart";
            type = recursiveAttrs;
            default = {};
          };

          kubeVersion = mkOption {
            description = "Kubernetes version to build chart for";
            type = types.str;
            default = globalConfig.kubernetes.version;
          };

          overrides = mkOption {
            description = "Overrides to apply to all chart resources";
            type = types.listOf types.unspecified;
            default = [];
          };

          overrideNamespace = mkOption {
            description = "Whether to apply namespace override";
            type = types.bool;
            default = true;
          };

          objects = mkOption {
            description = "Generated kubernetes objects";
            type = types.listOf types.attrs;
            default = [];
          };
        };

        config.overrides = mkIf (config.overrideNamespace && config.namespace != null) [{
          metadata.namespace = mkDefault config.namespace;
        }];

        config.objects = importJSON (chart2json {
          inherit (config) chart name namespace values kubeVersion;
        });
      }));
    };
  };

  # include helper helm methods as args
  config._module.args.helm = {
    fetch = fetchhelm;
    chart2json = chart2json;
  };

  config.kubernetes.api = mkMerge (flatten (mapAttrsToList (_: instance:
    map (object: let
      apiVersion = parseApiVersion object.apiVersion;
      name = object.metadata.name;
    in {
      "${apiVersion.group}"."${apiVersion.version}".${object.kind}."${name}" = mkMerge ([
        object
      ] ++ instance.overrides);
    }) instance.objects
  ) cfg.instances));
}
