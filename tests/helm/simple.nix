{ config, test, kubenix, k8s, helm, ... }:

with k8s;

let
  corev1 = config.kubernetes.api.core.v1;
  appsv1beta2 = config.kubernetes.api.apps.v1beta2;
in {
  imports = [
    kubenix.helm
  ];

  test = {
    name = "helm-simple";
    description = "Simple k8s testing wheter name, apiVersion and kind are preset";
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
        appsv1beta2.StatefulSet.app-psql-postgresql-master.metadata.namespace == "test-namespace";
    }];
  };

  kubernetes.api.namespaces.test-namespace = {};

  kubernetes.helm.instances.app-psql = {
    namespace = "test-namespace";
    chart = helm.fetch {
      chart = "stable/postgresql";
      version = "3.0.0";
      sha256 = "0icnnpcqvf1hqn7fc9niyifd0amlm9jfrx3iks0y360rk8wndbch";
    };

    values = {
      replication.enabled = true;
      replication.slaveReplicas = 2;
    };
  };
}
