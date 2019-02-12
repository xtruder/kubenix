{ config, pkgs, lib, kubenix, ... }:

with lib;

let
  cfg = config.testing;
in {
  options = {
    testing.throwError = mkOption {
      description = "Whether to throw error";
      type = types.bool;
      default = true;
    };

    testing.tests = mkOption {
      description = "Attribute set of test cases";
      default = [];
      type = types.listOf (types.coercedTo types.path (module: {inherit module;}) (types.submodule ({config, ...}: let
        modules = [config.module ./test.nix {
          config._module.args.test = config;
        }];

        test = (kubenix.evalKubernetesModules {
          check = false;
          inherit modules;
        }).config.test;

        evaled = builtins.trace "testing ${test.name}" (kubenix.evalKubernetesModules {
          inherit modules;
        });
      in {
        options = {
          module = mkOption {
            description = "Module defining submodule";
            type = types.unspecified;
          };

          name = mkOption {
            description = "test name";
            type = types.str;
            internal = true;
          };

          description = mkOption {
            description = "test description";
            type = types.str;
            internal = true;
          };

          evaled = mkOption {
            description = "Wheter test was evaled";
            type = types.bool;
            default =
              if cfg.throwError
              then if evaled.config.test.assertions != [] then true else true
              else (builtins.tryEval evaled.config.test.assertions).success;
            internal = true;
          };

          success = mkOption {
            description = "Whether test was success";
            type = types.bool;
            internal = true;
            default = false;
          };

          assertions = mkOption {
            description = "Test result";
            type = types.unspecified;
            internal = true;
            default = [];
          };
        };

        config = {
          inherit (test) name description;
          assertions = mkIf config.evaled evaled.config.test.assertions;
          success = mkIf config.evaled (all (el: el.assertion) config.assertions);
        };
      })));
    };

    testing.success = mkOption {
      description = "Whether testing was a success";
      type = types.bool;
      default = all (test: test.success) cfg.tests;
    };

    testing.result = mkOption {
      description = "Testing result";
      type = types.package;
      default = pkgs.writeText "testing-report.json" (builtins.toJSON {
        success = cfg.success;
        tests = map (test: {
          inherit (test) name description evaled success;
          assertions = moduleToAttrs test.assertions;
        }) cfg.tests;
      });
    };
  };
}
