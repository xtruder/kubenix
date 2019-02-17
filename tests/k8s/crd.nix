{ config, lib, kubenix, ... }:

with lib;

let
  cfg = config.kubernetes.api.customresourcedefinitions.crontabs;
in {
  imports = [
    kubenix.k8s
  ];

  test = {
    name = "k8s/crd";
    description = "Simple test tesing CRD";
    enable = builtins.compareVersions config.kubernetes.version "1.8" >= 0;
    assertions = [{
      message = "should have group set";
      assertion = cfg.spec.group == "stable.example.com";
    }];
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
}
