{ config, kubenix, ... }:

{
  imports = [ kubenix.modules.test kubenix.modules.metacontroller ];

  test = {
    name = "metacontroller-controllers";
    description = "Testing metacontroller custom resources";
  };

  kubernetes.api.compositecontrollers.test = {
    spec = {
      generateSelector = true;
      parentResource = {
        apiVersion = "ctl.enisoc.com/v1";
        resource = "things";
      };
      childResources = [{
        apiVersion = "v1";
        resource = "pods";
      }];
      hooks.sync.webhook.url = "http://thing-controller.metacontroller/sync";
    };
  };
}
