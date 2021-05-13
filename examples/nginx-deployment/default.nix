{ kubenix ? import ../.. { }, registry ? "docker.io/gatehub" }:

with kubenix.lib;

rec {
  # evaluated configuration
  config = (kubenix.evalModules {
    modules = [
      ./module.nix
      { docker.registry.url = registry; }

      kubenix.modules.testing
      {
        testing.tests = [ ./test.nix ];
        testing.defaults = ({ lib, ... }: with lib; {
          docker.registry.url = mkForce "";
          kubernetes.version = config.kubernetes.version;
        });
      }
    ];
  }).config;

  # e2e test
  test = config.testing.result;

  # nixos test script for running the test
  test-script = config.testing.testsByName.nginx-deployment.test;

  # genreated kubernetes List object
  generated = config.kubernetes.generated;

  # JSON file you can deploy to kubernetes
  result = config.kubernetes.result;

  # Exported docker images
  images = config.docker.export;

  # script to push docker images to registry
  pushDockerImages = config.docker.copyScript;
}
