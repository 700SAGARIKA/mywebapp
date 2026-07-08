resource "kubernetes_manifest" "app_prometheus_rules" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "app-alerts"
      namespace = "monitoring"
      labels = {
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "app.rules"
          rules = [
            {
              alert = "PodCrashLooping"
              expr  = "rate(kube_pod_container_status_restarts_total[5m]) > 0"
              for   = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Pod {{ $labels.pod }} is crash-looping"
                description = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} has restarted recently."
              }
            },
            {
              alert = "HighNodeCPU"
              expr  = "(1 - avg by(instance)(rate(node_cpu_seconds_total{mode=\"idle\"}[2m]))) * 100 > 85"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High CPU on {{ $labels.instance }}"
                description = "Node CPU usage is above 85% for 5 minutes."
              }
            },
            {
              alert = "HighMemoryUsage"
              expr  = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "High memory on {{ $labels.instance }}"
                description = "Node memory usage is above 90%."
              }
            },
            {
              alert = "PodNotReady"
              expr  = "kube_pod_status_ready{condition=\"true\"} == 0"
              for   = "2m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.pod }} is not ready"
                description = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} has been unready for 2 minutes."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus_stack]
}
