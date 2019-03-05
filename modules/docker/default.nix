{ config, lib, ... }:

with lib;

{
  options.docker.registry.url = mkOption {
    description = "Default registry url where images are published";
    type = types.str;
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
          default = config.docker.registry.url;
        };
      };
    }));
    default = {};
  };

  options.docker.push = mkOption {
    description = "List of images to push";
    type = types.listOf (types.package);
    default = [];
  };

  config.docker.push = mapAttrsToList (_: i: i.image)
    (filterAttrs (_: i: i.registry != null)config.docker.images);
}
