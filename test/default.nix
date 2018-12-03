{ config, ... }:

{
  kubernetes.version = "1.11";

  require = [./modules.nix ./deployment.nix];
}
