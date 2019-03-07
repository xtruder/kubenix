{ config, lib, pkgs, kubenix, helm, ... }:

with lib;
with kubenix.lib;
with pkgs.dockerTools;

let
  corev1 = config.kubernetes.api.core.v1;
  appsv1beta2 = config.kubernetes.api.apps.v1beta2;

  postgresql = pullImage {
    imageName = "docker.io/bitnami/postgresql";
    imageDigest = "sha256:16485a9b19696958ab7259e0d2c3efa0ef7f300b6fd1beb13a6643e120970a05";
    sha256 = "0hqdkpk7s3wcy5qsy6dzgzqc0rbpavpghly350p97j1janxbyhc7";
    finalImageTag = "10.7.0";
  };

  postgresqlExporter = pullImage {
    imageName = "docker.io/wrouesnel/postgres_exporter";
    imageDigest = "sha256:dd8051322ceb8995d3d7f116041a2116815e01e88232a90f635ebde8dcc4d3f4";
    sha256 = "09mva5jx1g4v47s4lr1pkpfzzmxc7z9dnajfizffm3rxwl0qzjji";
    finalImageTag = "v0.4.7";
  };

  minideb = pullImage {
    imageName = "docker.io/bitnami/minideb";
    imageDigest = "sha256:363011b4ad5308e7f2aee505b80730cbaadf9d41ff87879403f567dd98cfb5cf";
    sha256 = "1vfyfdhmgidi7hc8kjflpq91vkzdqi9sj78g51ci8nyarclr808q";
    finalImageTag = "latest";
  };
in {
  imports = [ kubenix.modules.test kubenix.modules.helm kubenix.modules.k8s ];

  test = {
    name = "helm-simple";
    description = "Simple k8s testing wheter name, apiVersion and kind are preset";
    enable = builtins.compareVersions config.kubernetes.version "1.8" >= 0;
    assertions = [{
      message = "should have generated resources";
      assertion =
        appsv1beta2.StatefulSet ? "app-psql-postgresql-master" &&
        appsv1beta2.StatefulSet ? "app-psql-postgresql-slave" &&
        corev1.ConfigMap ? "app-psql-postgresql-init-scripts" &&
        corev1.Secret ? "app-psql-postgresql" &&
        corev1.Service ? "app-psql-postgresql-headless" ;
    } {
      message = "should have values passed";
      assertion = appsv1beta2.StatefulSet.app-psql-postgresql-slave.spec.replicas == 2;
    } {
      message = "should have namespace defined";
      assertion =
        appsv1beta2.StatefulSet.app-psql-postgresql-master.metadata.namespace == "test";
    }];
    testScript = ''
      $kube->waitUntilSucceeds("docker load < ${postgresql}");
      $kube->waitUntilSucceeds("docker load < ${postgresqlExporter}");
      $kube->waitUntilSucceeds("docker load < ${minideb}");
      $kube->waitUntilSucceeds("kubectl apply -f ${toYAML config.kubernetes.objects}");
      $kube->waitUntilSucceeds("PGPASSWORD=postgres ${pkgs.postgresql}/bin/psql -h app-psql-postgresql.test.svc.cluster.local -U postgres -l");
    '';
  };

  kubernetes.api.namespaces.test = {};

  kubernetes.helm.instances.app-psql = {
    namespace = "test";
    chart = helm.fetch {
      chart = "stable/postgresql";
      version = "3.0.0";
      sha256 = "0icnnpcqvf1hqn7fc9niyifd0amlm9jfrx3iks0y360rk8wndbch";
    };

    values = {
      image = {
        repository = "bitnami/postgresql";
        tag = "10.7.0";
        pullPolicy = "IfNotPresent";
      };
      volumePermissions.image = {
        repository = "bitnami/minideb";
        tag = "latest";
        pullPolicy = "IfNotPresent";
      };
      metrics.image = {
        repository = "wrouesnel/postgres_exporter";
        tag = "v0.4.7";
        pullPolicy = "IfNotPresent";
      };
      replication.enabled = true;
      replication.slaveReplicas = 2;
      postgresqlPassword = "postgres";
      persistence.enabled = false;
    };
  };
}
