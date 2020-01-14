{ lib }:

with lib;

rec {
  mkSecretOption = {description ? "", default ? {}}: mkOption ({
    inherit description;
    type = types.nullOr (types.submodule {
      options = {
        name = mkOption {
          description = "Name of the secret where secret is stored";
          type = types.str;
          default = default.name or null;
        };

        key = mkOption {
          description = "Name of the key where secret is stored";
          type = types.str;
          default = default.key or null;
        };
      };
    });
    default = {};
  } // (optionalAttrs (default == null) {
    default = null;
  }));

  secretToEnv = value: {
    valueFrom.secretKeyRef = {
      inherit (value) name key;
    };
  };

  # Creates kubernetes list from a list of kubernetes objects
  mkList = { items, labels ? {} }: {
    kind = "List";
    apiVersion = "v1";

    inherit items labels;
  };

  # Creates hashed kubernetes list from a list of kubernetes objects
  mkHashedList = { items, labels ? {} }: let
    hash = builtins.hashString "sha1" (builtins.toJSON items);

    labeledItems = map (item: recursiveUpdate item {
      metadata.labels."kubenix/hash" = hash;
    }) items;

  in mkList {
    items = labeledItems;
    labels = {
      "kubenix/hash" = hash;
    } // labels;
  };

  toBase64 = lib.toBase64;
  octalToDecimal = lib.octalToDecimal;
}
