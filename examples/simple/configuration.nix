{
  kubernetes.resources.deployments.nginx = {
    metadata.labels.app = "nginx";
    spec = {
      replicas = 3;
      selector.matchLabels.app = "nginx";
      template = {
        metadata.labels.app = "nginx";
        spec.containers.nginx = {
          name = "nginx";
          image = "nginx:1.7.9";
          ports."80" = {};
          resources.requests.cpu = "100m";
        };
      };
    };
  };

  kubernetes.resources.services.nginx = {
    spec.selector.app = "nginx";
    spec.ports."80".targetPort = 80;
  };
}
