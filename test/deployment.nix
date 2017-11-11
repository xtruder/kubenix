{lib, k8s, ...}:

with lib;

{
  config = {
    kubernetes.resources = {
      deployments.deployment = mkMerge [
        (k8s.loadJSON ./deployment.json)
        {
          metadata.name = "abcd";
          nix.dependencies = ["configMaps/configmap"];
        }
      ];
      configMaps.configmap = k8s.loadJSON ./configMap.json;
      namespaces.namespace = k8s.loadJSON ./namespace.json;
      daemonSets.daemonset = k8s.loadJSON ./daemonset.json;
      services.service = k8s.loadJSON ./service.json;
      customResourceDefinitions.cron = k8s.loadJSON ./crd.json;
    };

    kubernetes.customResources.cron.my-awesome-cron-object = k8s.loadJSON ./cr.json;
  };
}
