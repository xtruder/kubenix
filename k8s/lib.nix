{ lib, ... }:

with lib;

let
  k8s = {
    mkSecretOption = {description ? "", default ? {}}: mkOption {
      inherit description;
      type = types.nullOr (types.submodule {
        options = {
          name = mkOption {
            description = "Name of the secret where secret is stored";
            type = types.str;
          };

          key = mkOption {
            description = "Name of the key where secret is stored";
            type = types.str;
          };
        };

        config = mkDefault default;
      });
      default = {};
    };

    secretToEnv = value: {
      valueFrom.secretKeyRef = {
        inherit (value) name key;
      };
    };
  };
in {
  _module.args.k8s = k8s;
}
