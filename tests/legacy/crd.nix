{ options, config, lib, kubenix, pkgs, ... }:

with lib;
let
  findObject = { kind, name }: filter
    (object:
      object.kind == kind && object.metadata.name == name
    )
    config.kubernetes.objects;

  getObject = filter: head (findObject filter);

  hasObject = { kind, name }: length (findObject { inherit kind name; }) == 1;
in
{
  imports = with kubenix.modules; [ test k8s legacy ];

  test = {
    name = "legacy-crd";
    description = "Simple test tesing kubenix legacy integration with crds crd";
    enable = builtins.compareVersions config.kubernetes.version "1.15" <= 0;
    assertions = [{
      message = "should define crd in module";
      assertion =
        hasObject { kind = "SecretClaim"; name = "module-claim"; };
    }
      {
        message = "should define crd in root";
        assertion =
          hasObject { kind = "SecretClaim"; name = "root-claim"; };
      }];
  };

  kubernetes.namespace = "test";

  kubernetes.moduleDefinitions.secret-claim.module = { config, k8s, module, ... }: {
    options = {
      name = mkOption {
        description = "Name of the secret claim";
        type = types.str;
        default = module.name;
      };

      type = mkOption {
        description = "Type of the secret";
        type = types.enum [ "Opaque" "kubernetes.io/tls" ];
        default = "Opaque";
      };

      path = mkOption {
        description = "Secret path";
        type = types.str;
      };

      renew = mkOption {
        description = "Renew time in seconds";
        type = types.nullOr types.int;
        default = null;
      };

      data = mkOption {
        type = types.nullOr types.attrs;
        description = "Data to pass to get secrets";
        default = null;
      };
    };

    config = {
      kubernetes.resources.customResourceDefinitions.secret-claims = {
        kind = "CustomResourceDefinition";
        apiVersion = "apiextensions.k8s.io/v1beta1";
        metadata.name = "secretclaims.vaultproject.io";
        spec = {
          group = "vaultproject.io";
          version = "v1";
          scope = "Namespaced";
          names = {
            plural = "secretclaims";
            kind = "SecretClaim";
            shortNames = [ "scl" ];
          };
        };
      };

      kubernetes.customResources.secret-claims.claim = {
        metadata.name = config.name;
        spec = {
          inherit (config) type path;
        } // (optionalAttrs (config.renew != null) {
          inherit (config) renew;
        }) // (optionalAttrs (config.data != null) {
          inherit (config) data;
        });
      };
    };
  };

  kubernetes.modules.module-claim = {
    module = "secret-claim";
    configuration.path = "tokens/test";
  };

  kubernetes.customResources.secret-claims.root-claim = {
    spec = {
      path = "secrets/test2";
    };
  };
}
