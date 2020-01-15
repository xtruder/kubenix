{ lib, pkgs }:

with lib;

{
  copyDockerImages = { images,  dest, args ? "" }:
    pkgs.writeScriptBin "copy-docker-images" (concatMapStrings (image: ''
      #!${pkgs.bash}/bin/bash

      set -e

      echo "copying ${image.imageName}:${image.imageTag}"
      ${pkgs.skopeo}/bin/skopeo copy ${args} $@ docker-archive:${image} ${dest}/${image.imageName}:${image.imageTag}
    '') images);
}
