{ lib, pkgs }:

(import ./extra.nix { inherit pkgs lib; }) // {
  k8s = import ./k8s.nix { inherit lib; };
  docker = import ./docker.nix { inherit lib pkgs; };
  helm = import ./helm { inherit pkgs; };
}
