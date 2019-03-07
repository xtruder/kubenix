{ config, lib, ... }:

with lib;

let
  globalConfig = config;
in {
  options.docker.registry.url = mkOption {
    description = "Default registry url where images are published";
    type = types.str;
    default = "";
  };

  options.docker.images = mkOption {
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
          default = globalConfig.docker.registry.url;
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

  options.docker.export = mkOption {
    description = "List of images to export";
    type = types.listOf (types.package);
    default = [];
  };

  config.docker.export = mapAttrsToList (_: i: i.image)
    (filterAttrs (_: i: i.registry != null)config.docker.images);
}
