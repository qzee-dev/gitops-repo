resource "helm_release" "this" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    grafana = {
      enabled       = true
      adminPassword = var.grafana_admin_password
      persistence = {
        enabled = true
        size    = "10Gi"
      }
      ingress = { enabled = false }
    }
    prometheus = {
      ingress = { enabled = false }
      prometheusSpec = {
        retention = "15d"
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources = {
                requests = { storage = "20Gi" }
              }
            }
          }
        }
      }
    }
    alertmanager = { enabled = true }
  })]

  lifecycle {
    precondition {
      condition     = length(var.grafana_admin_password) >= 16
      error_message = "Set grafana_admin_password to a password with at least 16 characters."
    }
  }
}