# Grafana dashboards as code.
#
# The kube-prometheus-stack Grafana sidecar (grafana.sidecar.dashboards in
# charts/kube-prometheus-stack/values.yaml) watches for ConfigMaps labeled
# grafana_dashboard=1 in ALL namespaces and auto-loads/updates them in
# Grafana. Add a new dashboard by dropping a JSON file in terraform/dashboards/
# and a matching kubernetes_config_map block below - `terraform apply` is all
# that's needed to see the change reflected in Grafana.
resource "kubernetes_config_map" "grafana_dashboard_namespace_resources" {
  metadata {
    name      = "grafana-dashboard-namespace-resources"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "app.dashboard/Namespaces-pannel"
    }
  }

  data = {
    "namespace-resources.json" = file("${path.module}/dashboards/namespace-resources.json")
  }

  depends_on = [helm_release.prometheus_stack]
}
