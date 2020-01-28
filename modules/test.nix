{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.test;
in {
  options.test = {
    name = mkOption {
      description = "Test name";
      type = types.str;
    };

    description = mkOption {
      description = "Test description";
      type = types.str;
    };

    enable = mkOption {
      description = "Whether to enable test";
      type = types.bool;
      default = true;
    };

    assertions = mkOption {
      type = types.listOf (types.submodule {
        options = {
          assertion = mkOption {
            description = "assertion value";
            type = types.bool;
            default = false;
          };

          message = mkOption {
            description = "assertion message";
            type = types.str;
          };
        };
      });
      default = [];
      example = [ { assertion = false; message = "you can't enable this for that reason"; } ];
      description = ''
        This option allows modules to express conditions that must
        hold for the evaluation of the system configuration to
        succeed, along with associated error messages for the user.
      '';
    };

    extraCheckInputs = mkOption {
      description = "Extra check inputs";
      type = types.listOf types.package;
      default = [];
    };

    testScript = mkOption {
      description = "Script to run as part of testing";
      type = types.nullOr types.lines;
      default = null;
    };

    distro = mkOption {
      description = "Kubernetes distro to run the test with. Defaults to 'nixos', other option is 'k3s'";
      type = types.nullOr types.str;
      default = null;
    };

    extraConfiguration = mkOption {
      description = "Extra configuration for running test";
      type = types.unspecified;
      default = {};
    };
  };
}
