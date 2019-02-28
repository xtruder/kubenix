{ config, lib, kubenix, pkgs, ... }:

with lib;

let
  cfg = config.kubernetes.api.customresourcedefinitions.crontabs;
in {
  imports = [
    kubenix.k8s
  ];

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
    resource = "crontabs";
    description = "CronTabs resources";
    module = {
      options.schedule = mkOption {
        description = "Crontab schedule script";
        type = types.str;
      };
    };
  }];

  kubernetes.api.namespaces.test = {};

  kubernetes.api."stable.example.com"."v1".CronTab.crontab.spec.schedule = "* * * * *";
}
