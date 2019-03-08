{ config, lib, ... }:

with lib;

{
  imports = [ ../k8s.nix ];

  options.metacontroller = {
    compositeControllers = mkOption {
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        imports = [ ./compositecontroller.nix ];

        options = {
          name = mkOption {
            description = "Name of the composite controller";
            type = types.str;
            default = name;
          };
        };
      }));
      default = {};
    };
  };

  config = {
    kubernetes.customResources = [{
      group = "metacontroller.k8s.io";
      version = "v1alpha1";
      kind = "CompositeController";
      resource = "compositecontrollers";
      description = "Composite controller";
      alias = "compositecontrollers";
      module.imports = [ ./compositecontroller.nix ];
    }];
  };
}
