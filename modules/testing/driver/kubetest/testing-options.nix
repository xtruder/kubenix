{ lib, config, ... }:

with lib;

{
  options.testing.kubetest = {
    defaultHeader = mkOption {
      description = "Default test header";
      type = types.lines;
      default = ''
        import pytest
      '';
    };
  };
}
