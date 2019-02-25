{ name, config, lib, kubenix, ... }:

with lib;

let
  cfg = config.submodules.instances.instance;
in {
  imports = [
    kubenix.submodules
  ];

  test = {
    name = "submodules-simple";
    description = "Simple k8s submodule test";
    assertions = [{
      message = "Submodule name is set";
      assertion = cfg.name == "instance";
    } {
      message = "Submodule version is set";
      assertion = cfg.version == null;
    } {
      message = "Submodule config has submodule definition";
      assertion = cfg.config.submodule.name == "submodule";
    } {
      message = "Should have argument set";
      assertion = cfg.config.args.value == "test";
    } {
      message = "Should have submodule name set";
      assertion = cfg.config.args.name == "instance";
    }];
  };

  submodules.imports = [{
    module = {name, ...}: {
      config.submodule.name = "submodule";
      options.args.value = mkOption {
        description = "Submodule argument";
        type = types.str;
      };
      options.args.name = mkOption {
        description = "Submodule name";
        type = types.str;
        default = name;
      };
    };
  }];

  submodules.instances.instance = {
    submodule = "submodule";
    config = {name, ...}: {
      config.args.value = "test";
    };
  };
}
