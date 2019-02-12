{pkgs ? import <nixpkgs> {}}:

let
  kubenix = import ./. { inherit pkgs; };

  lib = kubenix.lib;

  generateK8S = path: import ./k8s/generator.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit path;
  };

  generateIstio = spec: import ./istio/generator.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit spec;
  };
in {
  generate.k8s = pkgs.linkFarm "k8s-generated.nix" [{
    name = "v1.7.nix";
    path = generateK8S ./k8s/specs/1.7/swagger.json;
  } {
    name = "v1.8.nix";
    path = generateK8S ./k8s/specs/1.8/swagger.json;
  } {
    name = "v1.9.nix";
    path = generateK8S ./k8s/specs/1.9/swagger.json;
  } {
    name = "v1.10.nix";
    path = generateK8S ./k8s/specs/1.10/swagger.json;
  }];

  generate.istio = pkgs.linkFarm "istio-generated.nix" [{
    name = "latest.nix";
    path = generateIstio ./istio/istio-schema.json;
  }];

  test = import ./test {
    inherit pkgs lib kubenix;
  };

  test-old = kubenix.buildResources ({
    module = {lib, config, kubenix, ...}: with lib; {
      imports = [
        kubenix.k8s
        kubenix.submodules
        kubenix.istio
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

        kubernetes.api."networking.istio.io"."v1alpha3".Gateway.test.spec = {
          selector.istio = "ingressgateway";
          servers = [{
            port = {
              number = 80;
              name = "http";
              protocol = "HTTP";
            };
            hosts = ["host.example.com"];
            tls.httpsRedirect = true;
          } {
            port = {
              number = 443;
              name = "https";
              protocol = "HTTPS";
            };
            hosts = ["host.example.com"];
            tls = {
              mode = "SIMPLE";
              serverCertificate = "/path/to/server.crt";
              privateKey = "/path/to/private.key";
              caCertificates = "/path/to/ca.crt";
            };
          }];
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
    };
  });
}
