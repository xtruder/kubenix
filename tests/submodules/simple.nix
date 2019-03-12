{ name, config, lib, kubenix, ... }:

with lib;

let
  cfg = config.submodules.instances.instance;
in {
  imports = with kubenix.modules; [ test submodules ];

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
    } {
      message = "should have tag set";
      assertion = elem "tag" (cfg.config.submodule.tags);
    }];
  };

  submodules.propagate.enable = true;
  submodules.imports = [{
    module = {name, ...}: {
      imports = [ kubenix.modules.submodule ];
      config = {
        submodule.name = "submodule";
        submodule.tags = ["tag"];
      };
      options = {
        args.value = mkOption {
          description = "Submodule argument";
          type = types.str;
        };
        args.name = mkOption {
          description = "Submodule name";
          type = types.str;
          default = name;
        };
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
