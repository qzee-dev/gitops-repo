resource "helm_release" "routes" {
  name             = "${var.environment}-aws-alb-routes"
  chart            = "${path.module}/../charts/routes"
  namespace        = "edge-gateway"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    controller   = "alb"
    environment  = var.environment
    appNamespace = var.app_namespace
    domainSuffix = var.domain_suffix
    hostnames = {
      frontend   = "app.${var.domain_suffix}"
      grafana    = var.grafana_hostname
      prometheus = var.prometheus_hostname
    }
    frontend   = { enabled = var.frontend_enabled }
    monitoring = { enabled = var.monitoring_enabled }
    logging = {
      enabled        = var.logging_enabled
      kibanaHostname = var.kibana_hostname
      kibanaService  = "kibana-kb-http"
    }
    tlsEnabled = true
    alb = {
      certificateArn = var.certificate_arn
      scheme         = var.alb_scheme
      groupName      = "${var.environment}-sample-endpoints"
    }
  })]

}
