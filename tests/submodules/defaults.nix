{ name, config, lib, kubenix, ... }:

with lib;

let
  instance1 = config.submodules.instances.instance1;
  instance2 = config.submodules.instances.instance2;
  instance3 = config.submodules.instances.instance3;
  instance4 = config.submodules.instances.instance4;
  instance5 = config.submodules.instances.instance5;

  submodule = {name, ...}: {
    imports = [ kubenix.modules.submodule ];

    options = {
      args.value = mkOption {
        description = "Submodule value";
        type = types.str;
      };

      args.defaultValue = mkOption {
        description = "Submodule default value";
        type = types.str;
      };
    };
  };
in {
  imports = with kubenix.modules; [ test submodules ];

  test = {
    name = "submodules-defaults";
    description = "Simple submodule test";
    assertions = [{
      message = "should apply defaults by tag1";
      assertion = instance1.config.args.value == "value1";
    } {
      message = "should apply defaults by tag2";
      assertion = instance2.config.args.value == "value2";
    } {
      message = "should apply defaults by tag2";
      assertion = instance3.config.args.value == "value2";
    } {
      message = "should apply defaults to all";
      assertion =
        instance1.config.args.defaultValue == "value" &&
        instance2.config.args.defaultValue == "value";
    } {
      message = "instance1 and instance3 should have value of default-value";
      assertion = instance3.config.args.defaultValue == "default-value";
    } {
      message = "should apply defaults by submodule name";
      assertion = instance4.config.args.value == "value4";
    } {
      message = "should apply defaults by custom condition";
      assertion = instance5.config.args.defaultValue == "my-custom-value";
    }];
  };

  submodules.imports = [{
    modules = [submodule {
      submodule = {
        name = "submodule1";
        tags = ["tag1"];
      };
    }];
  } {
    modules = [submodule {
      submodule = {
        name = "submodule2";
        tags = ["tag2"];
      };
    }];
  } {
    modules = [submodule {
      submodule = {
        name = "submodule3";
        tags = ["tag2"];
      };
    }];
  } {
    modules = [submodule {
      submodule = {
        name = "submodule4";
      };
    }];
  } {
    modules = [submodule {
      submodule = {
        name = "submodule5";
      };
      args.value = "custom-value";
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
  } {
    default = {config, ...}: {
      args.defaultValue = mkIf (config.args.value == "custom-value") "my-custom-value";
    };
  }];

  submodules.instances.instance1.submodule = "submodule1";
  submodules.instances.instance2.submodule = "submodule2";
  submodules.instances.instance3 = {
    submodule = "submodule3";
    config.args.defaultValue = "default-value";
  };
  submodules.instances.instance4.submodule = "submodule4";
  submodules.instances.instance5.submodule = "submodule5";
}
