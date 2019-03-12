{ config, lib, ... }:

with lib;

{
  options._module.features = mkOption {
    description = "List of features exposed by module";
    type = types.listOf types.str;
    default = [];
  };

  options.kubenix = {
    project = mkOption {
      description = "Name of the project";
      type = types.str;
      default = "kubenix";
    };
  };
}
