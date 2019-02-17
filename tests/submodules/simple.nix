{ config, lib, kubenix, ... }:

with lib;

{
  imports = [
    kubenix.submodules
  ];

  test = {
    name = "submodules/simple";
    description = "Simple k8s submodule test";
    assertions = [{
      message = "Submodule name is set";
      assertion = config.submodules.instances.empty.name == "empty";
    } {
      message = "Submodule version is set";
      assertion = config.submodules.instances.empty.version == null;
    } {
      message = "Submodule config has submodule definition";
      assertion = config.submodules.instances.empty.config.submodule.name == "empty";
    } {
      message = "Should have argument set";
      assertion = config.submodules.instances.empty.config.args.value == "test";
    }];
  };

  submodules.imports = [{
    module = {
      config.submodule.name = "empty";
      options.args.value = mkOption {
        description = "Submodule argument";
        type = types.str;
      };
    };
  }];

  submodules.instances.empty = {
    config.args.value = "test";
  };
}
