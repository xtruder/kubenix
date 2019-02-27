{ config, test, kubenix, k8s, ... }:

with k8s;

{
  imports = [
    kubenix.k8s
    kubenix.istio
  ];

  test = {
    name = "istio-bookinfo";
    description = "Simple istio bookinfo application (WIP)";
  };

  kubernetes.api."networking.istio.io"."v1alpha3" = {
    Gateway."bookinfo-gateway" = {
      spec = {
        selector.istio = "ingressgateway";
        servers = [{
          port = {
            number = 80;
            name = "http";
            protocol = "HTTP";
          };
          hosts = ["*"];
        }];
      };
    };

    VirtualService.bookinfo = {
      spec = {
        hosts = ["*"];
        gateways = ["bookinfo-gateway"];
        http = [{
          match = [{
            uri.exact = "/productpage";
          } {
            uri.exact = "/login";
          } {
            uri.exact = "/logout";
          } {
            uri.prefix = "/api/v1/products";
          }];
          route = [{
            destination = {
              host = "productpage";
              port.number = 9080;
            };
          }];
        }];
      };
    };
  };
}
