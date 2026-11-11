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
      additionalDataSources = [{
        name      = "Tempo"
        type      = "tempo"
        access    = "proxy"
        url       = "http://tempo.monitoring.svc.cluster.local:3100"
        uid       = "tempo"
        isDefault = false
      }]
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
        additionalScrapeConfigs = <<-EOT
          - job_name: opentelemetry-collector
            honor_labels: true
            static_configs:
              - targets: ["opentelemetry-collector.monitoring.svc:8889"]
            metrics_path: /metrics
            scrape_interval: 30s
        EOT
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

resource "helm_release" "tempo" {
  name             = "tempo"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "tempo"
  version          = var.tempo_chart_version
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    tempo = {
      reportingEnabled = false
      retention = "24h"
      receivers = {
        otlp = {
          protocols = {
            grpc = { endpoint = "0.0.0.0:4317" }
            http = { endpoint = "0.0.0.0:4318" }
          }
        }
      }
    }
      persistence = {
        enabled = true
        size    = "20Gi"
      }
    service = {
      type = "ClusterIP"
    }
  })]

  depends_on = [helm_release.this]
}

resource "helm_release" "opentelemetry_collector" {
  name             = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = var.otel_collector_chart_version
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [templatefile("${path.module}/otel-collector-values.yaml", {
    environment = var.environment
  })]

  depends_on = [helm_release.this, helm_release.tempo]
}