{ name, config, lib, kubenix, ... }:

with lib;

let
  instance1 = config.submodules.instances.instance1;
  instance2 = config.submodules.instances.instance2;
  instance3 = config.submodules.instances.instance3;
  instance4 = config.submodules.instances.instance4;

  module = {name, ...}: {
    options.args.value = mkOption {
      description = "Submodule value";
      type = types.str;
    };

    options.args.defaultValue = mkOption {
      description = "Submodule default value";
      type = types.str;
    };
  };
in {
  imports = [
    kubenix.submodules
  ];

  test = {
    name = "submodules-defatuls";
    description = "Simple k8s submodule test";
    assertions = [{
      message = "instance1 should have value of value1";
      assertion = instance1.config.args.value == "value1";
    } {
      message = "instance2 should have value of value2";
      assertion = instance2.config.args.value == "value2";
    } {
      message = "instance2 should have value of value2";
      assertion = instance3.config.args.value == "value2";
    } {
      message = "instance1 and instance2 should have value of value";
      assertion =
        instance1.config.args.defaultValue == "value" &&
        instance2.config.args.defaultValue == "value";
    } {
      message = "instance1 and instance3 should have value of default-value";
      assertion = instance3.config.args.defaultValue == "default-value";
    } {
      message = "instance4 should have value of value4";
      assertion = instance4.config.args.value == "value4";
    }];
  };

  submodules.imports = [{
    modules = [module {
      submodule = {
        name = "submodule1";
        tags = ["tag1"];
      };
    }];
  } {
    modules = [module {
      submodule = {
        name = "submodule2";
        tags = ["tag2"];
      };
    }];
  } {
    modules = [module {
      submodule = {
        name = "submodule3";
        tags = ["tag2"];
      };
    }];
  } {
    modules = [module {
      submodule = {
        name = "submodule4";
      };
    }];
  }];

  submodules.defaults = [{
    default.args.defaultValue = mkDefault "value";
  } {
    tags = ["tag1"];
    default.args.value = mkDefault "value1";
  } {
    tags = ["tag2"];
    default.args.value = mkDefault "value2";
  } {
    name = "submodule4";
    default.args.value = mkDefault "value4";
  }];

  submodules.instances.instance1.submodule = "submodule1";
  submodules.instances.instance2.submodule = "submodule2";
  submodules.instances.instance3 = {
    submodule = "submodule3";
    config.args.defaultValue = "default-value";
  };
  submodules.instances.instance4.submodule = "submodule4";
}
