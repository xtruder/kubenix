{ config, ... }:

{
  kubernetes.version = "1.7";

  require = [./modules.nix ./deployment.nix];
}
