{pkgs ? import <nixpkgs> {}}:

let
  generate = path: import ./k8s/generator.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit path;
  };

  kubenix = import ./. { inherit pkgs; };
in {
  generate = pkgs.linkFarm "k8s-generated.nix" [{
    name = "v1.7.nix";
    path = generate ./k8s/specs/1.7/swagger.json;
  } {
    name = "v1.8.nix";
    path = generate ./k8s/specs/1.8/swagger.json;
  } {
    name = "v1.9.nix";
    path = generate ./k8s/specs/1.9/swagger.json;
  } {
    name = "v1.10.nix";
    path = generate ./k8s/specs/1.10/swagger.json;
  }];

  test = kubenix.buildResources ({lib, config, kubenix, ...}: with lib; {
    imports = [
      kubenix.k8s
      kubenix.submodules
    ];

    config = {
      kubernetes.version = "1.10";

      kubernetes.api.defaults.all.metadata.namespace = mkDefault "my-namespace";

      submodules.defaults = {config, parentConfig, ...}: {
        kubernetes = mkIf (hasAttr "kubernetes" config) {
          version = mkDefault parentConfig.kubernetes.version;
          api.defaults = mkDefault parentConfig.kubernetes.api.defaults;
        };
      };

      submodules.imports = [
        # import nginx submodule
        ./examples/module/nginx.nix

        # import of patched nginx submodule
        {
          modules = [./examples/module/nginx.nix ({config, ...}: {
            config = {
              submodule.version = mkForce "1.0-xtruder";
              args.image = "xtruder/nginx";

              submodules.instances.test2 = {
                submodule = "test";
              };

              kubernetes.objects = config.submodules.instances.test2.config.kubernetes.objects;
            };
          })];
        }

        # definition of test submodule
        {
          module = {submodule, ...}: {
            submodule.name = "test";

            imports = [
              kubenix.k8s
            ];

            kubernetes.api.Pod.my-pod = {
              metadata.name = submodule.name;
            };
          };
        }
      ];

      submodules.instances.nginx-default = {
        submodule = "nginx";
      };

      submodules.instances.nginx-xtruder = {
        submodule = "nginx";
        version = "1.0-xtruder";

        config = {
          args.replicas = 9;
          kubernetes.api.Deployment.nginx.metadata.namespace = "other-namespace";
        };
      };

      submodules.instances.test = {
        submodule = "test";
      };

      #kubernetes.api."cloud.google.com".v1beta1.BackendConfig.my-backend = {
      #};

      #modules.nginx1 = {
        #args = {
          #replicas = 2;
        #};

        #kubernetes.api.defaults.deployments = {
          #spec.replicas = mkForce 3;
        #};

        #kubernetes.customResources = [{
          #group = "cloud.google.com";
          #version = "v1beta1";
          #kind = "BackendConfig";
          #plural = "backendconfigs";
          #description = "Custom resource";
          #module = {
            #options.spec = {
              #cdn = mkOption {
                #description = "My cdn";
                #type = types.str;
                #default = "test";
              #};
            #};
          #};
        #}];
      #};

      #modules.nginx2 = {
        #args = {
          #replicas = 2;
        #};

        #kubernetes.api.defaults.deployments = {
          #spec.replicas = mkForce 3;
        #};
      #};

      kubernetes.objects = mkMerge [
        config.submodules.instances.nginx-default.config.kubernetes.objects
        config.submodules.instances.nginx-xtruder.config.kubernetes.objects
        config.submodules.instances.test.config.kubernetes.objects
      ];

      #kubernetes.customResources = config.modules.nginx1.kubernetes.customResources;
    };
  });
}
