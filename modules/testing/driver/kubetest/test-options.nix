{ lib, config, ... }:

with lib;

let
  cfg = config.kubetest;

in {
  options.test.kubetest = {
    enable = mkOption {
      description = "Whether to use kubetest test driver";
      type = types.bool;
      default = cfg.testScript != "";
    };

    testScript = mkOption {
      type = types.lines;
      description = "Test script to use for kubetest";
      default = "";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      description = "List of extra packages to use for kubetest";
      default = [];
    };
  };
}
