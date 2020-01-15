{ config, lib, kubenix, k8sVersion, ... }:

with lib;

let
  cfg = config.kubernetes.resources.customResourceDefinitions.crontabs;
in {
  imports = with kubenix.modules; [ test k8s ];

  test = {
    name = "k8s-1-13-crd";
    description = "Simple test testing CRD for k8s 1.13";
    enable = builtins.compareVersions config.kubernetes.version "1.13" >= 0;
    assertions = [{
      message = "should have versions set";
      assertion = (head cfg.spec.versions).name == "v1";
    }];
  };

  kubernetes.version = k8sVersion;

  kubernetes.resources.customResourceDefinitions.crontabs = {
    metadata.name = "crontabs.stable.example.com";
    spec = {
      group = "stable.example.com";
      versions = [{
        name = "v1";
        served = true;
        storage = true;
      }];
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
