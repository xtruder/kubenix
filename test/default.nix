{ config, ... }:

{
  kubernetes.version = "1.9";

  require = [./modules.nix ./deployment.nix];
}
