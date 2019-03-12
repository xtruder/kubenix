{ config, lib, ... }:

with lib;

let
  cfg = config.docker;
in {
  options.docker = {
    registry.url = mkOption {
      description = "Default registry url where images are published";
      type = types.str;
      default = "";
    };

    images = mkOption {
      description = "Attribute set of docker images that should be published";
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        options = {
          image = mkOption {
            description = "Docker image to publish";
            type = types.nullOr types.package;
            default = null;
          };

          name = mkOption {
            description = "Desired docker image name";
            type = types.str;
            default = builtins.unsafeDiscardStringContext config.image.imageName;
          };

          tag = mkOption {
            description = "Desired docker image tag";
            type = types.str;
            default = builtins.unsafeDiscardStringContext config.image.imageTag;
          };

          registry = mkOption {
            description = "Docker registry url where image is published";
            type = types.str;
            default = cfg.registry.url;
          };

          path = mkOption {
            description = "Full docker image path";
            type = types.str;
            default =
              if config.registry != ""
              then "${config.registry}/${config.name}:${config.tag}"
              else "${config.name}:${config.tag}";
          };
        };
      }));
      default = {};
    };

    export = mkOption {
      description = "List of images to export";
      type = types.listOf (types.package);
      default = [];
    };
  };

  config = {
    _module.features = ["docker"];

    docker.export = mkMerge [
      (mapAttrsToList (_: i: i.image)
        (filterAttrs (_: i: i.registry != null) config.docker.images))

      # passthru of docker exported images if passthru is enabled on submodule
      # and submodule has docker module loaded
      (flatten (mapAttrsToList (_: submodule:
        optionals
          (submodule.passthru.enable && (elem "docker" submodule.config._module.features))
          submodule.config.docker.export
      ) config.submodules.instances))
    ];
  };
}
