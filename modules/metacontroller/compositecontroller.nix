{ config, lib, ... }:

with lib;

{
  options = {
    parentResource = {
      apiVersion = mkOption {
        description = "Parent resource apiVersion";
        type = types.str;
        example = "apps/v1";
      };

      resource = mkOption {
        description = "The canonical, lowercase, plural name of the parent resource";
        type = types.str;
        example = "deployments";
      };

      revisionHistory = mkOption {
        description = "A list of field path strings specifying which parent fields trigger rolling updates of children";
        type = types.listOf types.str;
        default = ["spec"];
        example = ["spec.template"];
      };
    };

    childResources = mkOption {
      description = "A list of resource rules specifying the child resources";
      type = types.listOf (types.submodule ({ config, ... }: {
        options = {
          apiVersion = mkOption {
            description = "The API group/version of the child resource, or just version for core APIs";
            type = types.str;
            example = "apps/v1";
          };

          resource = mkOption {
            description = "The canonical, lowercase, plural name of the child resource";
            type = types.str;
            example = "deployments";
          };

          updateStrategy = {
            method = mkOption {
              description = ''
                A string indicating the overall method that should be used for updating this type of child resource.
                The default is OnDelete, which means don't try to update children that already exist.

                - OnDelete: Don't update existing children unless they get deleted by some other agent.
                - Recreate: Immediately delete any children that differ from the desired state, and recreate them in the desired state.
                - InPlace: Immediately update any children that differ from the desired state.
                - RollingRecreate: Delete each child that differs from the desired state, one at a time,
                  and recreate each child before moving on to the next one.
                  Pause the rollout if at any time one of the children that have already been updated fails one or more status checks.
                - RollingInPlace: Update each child that differs from the desired state, one at a time. Pause the rollout if at any time
                  one of the children that have already been updated fails one or more status checks.
              '';
              type = types.enum [
                "OnDelete"
                "Recreate"
                "InPlace"
                "RollingRecreate"
                "RollingInPlace"
              ];
              default = "OnDelete";
            };

            statusChecks.conditions = mkOption {
              description = ''
                A list of status condition checks that must all pass on already-updated
                children for the rollout to continue.
              '';
              type = types.listOf (types.submodule ({ config, ... }: {
                options = {
                  type = mkOption {
                    description = "A string specifying the status condition type to check.";
                    type = types.str;
                  };

                  status = mkOption {
                    description = ''
                      A string specifying the required status of the given status condition.
                      If none is specified, the condition's status is not checked.
                    '';
                    type = types.str;
                    default = "";
                  };

                  reason = mkOption {
                    description = ''
                      A string specifying the required reason of the given status condition.
                      If none is specified, the condition's reason is not checked.
                    '';
                    type = types.str;
                    default = "";
                  };
                };
              }));
              default = [];
            };
          };
        };
      }));
      default = [];
    };

    resyncPeriodSeconds = mkOption {
      description = ''
        How often, in seconds, you want every parent object to be resynced,
        even if no changes are detected.
      '';
      type = types.int;
      default = 0;
    };

    generateSelector = mkOption {
      description = ''
        If true, ignore the selector in each parent object and instead generate
        a unique selector that prevents overlap with other objects.
      '';
      type = types.bool;
      default = false;
    };

    hooks = {
      sync.webhook.url = mkOption {
        description = "Webhook URL where to send sync request";
        type = types.str;
      };

      finalize.webhook.url = mkOption {
        description = "Webhook URL where to send finalize request";
        type = types.str;
        default = "";
      };
    };
  };
}
