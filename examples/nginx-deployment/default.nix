{ kubenix ? import ../.. {} }:

with kubenix.lib;

let
  registy = "docker.io/gatehub";
in rec {
  # evaluated configuration
  config = (kubenix.evalModules {
    modules = [
      ./module.nix
      { docker.registry.url = registy; }
    ];
  }).config;

  # list of kubernetes objects
  objects = config.kubernetes.objects;

  # hashed kubernetes List object
  listObject = k8s.mkHashedList { items = config.kubernetes.objects; };

  # YAML file you can deploy to kubernetes
  yaml = toYAML listObject;

  # Exported docker images
  images = config.docker.export;

  # script to push docker images to registry
  pushDockerImages = docker.copyDockerImages {
    inherit images;
    dest = "docker://${registy}";
  };
}
