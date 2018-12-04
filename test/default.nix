{ config, ... }:

{
  require = [./modules.nix ./deployment.nix];
}
