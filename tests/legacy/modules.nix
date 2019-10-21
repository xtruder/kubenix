{ options, config, lib, kubenix, pkgs, k8sVersion, ... }:

with lib;

let
  findObject = { kind, name }: filter (object:
    object.kind == kind && object.metadata.name == name
  ) config.kubernetes.objects;

  getObject = filter: head (findObject filter);

  hasObject = { kind, name }: length (findObject { inherit kind name; }) == 1;
in {
  imports = with kubenix.modules; [ test k8s legacy ];

  test = {
    name = "legacy-modules";
    description = "Simple test tesing kubenix legacy modules";
    assertions = [{
    message = "should have all objects";
    assertion =
      hasObject {kind = "Deployment"; name = "myapp";} &&
      hasObject {kind = "Deployment"; name = "myapp2";} &&
      hasObject {kind = "Deployment"; name = "myapp2-app2";};
    } {
      message = "should have default labels set";
      assertion =
        (getObject {kind = "Deployment"; name = "myapp2-app2";})
          .metadata.labels.module-label or false == "value" &&
        (getObject {kind = "Deployment"; name = "myapp2";})
          .metadata.labels.module-label or false == "value";
    } {
      message = "should passthru resources to root module";
      assertion =
        config.kubernetes.resources.deployments.myapp2-app2-app.metadata.labels.module-label or false == "value";
    }];
  };

  kubernetes.version = k8sVersion;

  kubernetes.defaults.all.metadata.labels.module-label = "value";

  # propagate default module configuration and defaults
  kubernetes.defaultModuleConfiguration = {
    all.kubernetes.defaultModuleConfiguration = mkAliasDefinitions options.kubernetes.defaultModuleConfiguration;
    all.kubernetes.defaults = mkAliasDefinitions options.kubernetes.defaults;
  };

  kubernetes.moduleDefinitions.app1.module = { config, k8s, module, ... }: {
    config.kubernetes.resources.deployments.app = {
      metadata.name = module.name;
      spec = {
        selector = {
          matchLabels.app = "app";
        };
        template.spec = {
          containers.app = {
            image = "hello-world";
          };
        };
      };
    };
  };

  kubernetes.moduleDefinitions.app2.module = { name, config, k8s, module, ... }: {
    options = {
      replicas = mkOption {
        description = "Number of replicas to run";
        type = types.int;
        default = 2;
      };
    };

    config = {
      kubernetes.resources.deployments.app = {
        metadata.name = module.name;
        spec = {
          replicas = config.replicas;
          selector = {
            matchLabels.app = "app";
          };
          template.spec = {
            containers.app = {
              image = "hello-world";
            };
          };
        };
      };

      kubernetes.modules.app2 = {
        name = "${name}-app2";
        module = "app1";
        namespace = module.namespace;
      };
    };
  };

  kubernetes.modules.myapp = {
    module = "app1";
    namespace = "test";
  };

  kubernetes.modules.myapp2 = {
    module = "app2";
    namespace = "test";
    configuration.replicas = 3;
  };
}
