{ config, lib, kubenix, pkgs, k8sVersion, ... }:

with lib;

let
  cfg = config.kubernetes.api.resources.customResourceDefinitions.crontabs;
in {
  imports = with kubenix.modules; [ test k8s ];

  test = {
    name = "k8s-order";
    description = "test tesing k8s resource order";
    enable = builtins.compareVersions config.kubernetes.version "1.8" >= 0;
    assertions = [{
      message = "should have correct order of resources";
      assertion =
        (elemAt config.kubernetes.objects 0).kind == "CustomResourceDefinition" &&
        (elemAt config.kubernetes.objects 1).kind == "Namespace" &&
        (elemAt config.kubernetes.objects 2).kind == "CronTab";
    }];
  };

  kubernetes.version = k8sVersion;

  kubernetes.resources.customResourceDefinitions.crontabs = {
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

  kubernetes.customTypes = [{
    name = "crontabs";
    description = "CronTabs resources";

    group = "stable.example.com";
    version = "v1";
    kind = "CronTab";
    module = {
      options.schedule = mkOption {
        description = "Crontab schedule script";
        type = types.str;
      };
    };
  }];

  kubernetes.resources.namespaces.test = {};

  kubernetes.resources."stable.example.com"."v1".CronTab.crontab.spec.schedule = "* * * * *";
}
