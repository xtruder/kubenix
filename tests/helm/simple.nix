{ config, lib, pkgs, kubenix, helm, k8sVersion, ... }:

with lib;
with kubenix.lib;
with pkgs.dockerTools;

let
  corev1 = config.kubernetes.api.resources.core.v1;
  appsv1 = config.kubernetes.api.resources.apps.v1;

  postgresql = pullImage {
    imageName = "docker.io/bitnami/postgresql";
    imageDigest = "sha256:ec16eb9ff2e7bf0669cfc52e595f17d9c52efd864c3f943f404d525dafaaaf96";
    sha256 = "1idl8amp2jifc71lq8ymyns41d76cnasqbxyaild0gjzlpxmsn9n";
    finalImageTag = "11.7.0-debian-10-r55";
  };

  postgresqlExporter = pullImage {
    imageName = "docker.io/bitnami/postgres-exporter";
    imageDigest = "sha256:08ab46104b83834760a5e0329af11de23ccf920b4beffd27c506f34421920313";
    sha256 = "14yw8fp6ja7x1wn3lyw8ws5lc5z9jz54vdc5ad5s7yxjfs0jvk6d";
    finalImageTag = "0.8.0-debian-10-r66";
  };

  minideb = pullImage {
    imageName = "docker.io/bitnami/minideb";
    imageDigest = "sha256:2f430acaa0ffd88454ac330a6843840f1e1204007bf92f8ce7b654fd3b558d68";
    sha256 = "1h589digi99jvpdzn3azx4p8hlh7plci04him9vfmx2vfa5zxq4i";
    finalImageTag = "buster";
  };
in {
  imports = [ kubenix.modules.test kubenix.modules.helm kubenix.modules.k8s ];

  test = {
    name = "helm-simple";
    description = "Simple k8s testing wheter name, apiVersion and kind are preset";
    assertions = [{
      message = "should have generated resources";
      assertion =
        appsv1.StatefulSet ? "app-psql-postgresql-master" &&
        appsv1.StatefulSet ? "app-psql-postgresql-slave" &&
        corev1.Secret ? "app-psql-postgresql" &&
        corev1.Service ? "app-psql-postgresql-headless" ;
    } {
      message = "should have values passed";
      assertion = appsv1.StatefulSet.app-psql-postgresql-slave.spec.replicas == 2;
    } {
      message = "should have namespace defined";
      assertion =
        appsv1.StatefulSet.app-psql-postgresql-master.metadata.namespace == "test";
    }];
    testScript = ''
      kube.wait_until_succeeds("docker load < ${postgresql}")
      kube.wait_until_succeeds("docker load < ${postgresqlExporter}")
      kube.wait_until_succeeds("docker load < ${minideb}")
      kube.wait_until_succeeds("kubectl apply -f ${config.kubernetes.result}")
      kube.wait_until_succeeds("PGPASSWORD=postgres ${pkgs.postgresql}/bin/psql -h app-psql-postgresql.test.svc.cluster.local -U postgres -l")
    '';
  };

  kubernetes.version = k8sVersion;

  kubernetes.resources.namespaces.test = {};

  kubernetes.helm.instances.app-psql = {
    namespace = "test";
    chart = helm.fetch {
      repo = "https://charts.bitnami.com/bitnami";
      chart = "postgresql";
      version = "8.6.13";
      sha256 = "pYJuxr5Ec6Yjv/wFn7QAA6vCiVjNTz1mWoexdxwiEzE=";
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
