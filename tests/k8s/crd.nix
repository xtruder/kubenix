{ config, lib, kubenix, pkgs, ... }:

with lib;

let
  cfg = config.kubernetes.api.customresourcedefinitions.crontabs;
in {
  imports = [
    kubenix.k8s
  ];

  test = {
    name = "k8s.crd";
    description = "Simple test tesing CRD";
    enable = builtins.compareVersions config.kubernetes.version "1.8" >= 0;
    assertions = [{
      message = "should have group set";
      assertion = cfg.spec.group == "stable.example.com";
    }];
    check = ''
      $kube->waitUntilSucceeds("kubectl apply -f ${toYAML config.kubernetes.generated}");
      $kube->succeed("kubectl get crds | grep -i crontabs");
      $kube->succeed("kubectl get crontabs | grep -i crontab");
    '';
  };

  kubernetes.api.customresourcedefinitions.crontabs = {
    metadata.name = "crontabs.stable.example.com";
    spec = {
      group = "stable.example.com";
      version = "v1";
      scope = "Namespaced";
      names = {
        plural = "crontabs";
        singular = "crontab";
        kind = "CronTab";
        shortNames = ["ct"];
      };
    };
  };

  kubernetes.customResources = [{
    group = "stable.example.com";
    version = "v1";
    kind = "CronTab";
    plural = "crontabs";
    description = "CronTabs resources";
    module = {
      options.schedule = mkOption {
        description = "Crontab schedule script";
        type = types.str;
      };
    };
  }];

  kubernetes.api."stable.example.com"."v1".CronTab.crontab.spec.schedule = "* * * * *";
}
