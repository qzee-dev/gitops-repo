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
      grafana    = "grafana.${var.domain_suffix}"
      prometheus = "prometheus.${var.domain_suffix}"
    }
    frontend   = { enabled = var.frontend_enabled }
    monitoring = { enabled = var.monitoring_enabled }
    tlsEnabled = true
    alb = {
      certificateArn = var.certificate_arn
      scheme         = var.alb_scheme
      groupName      = "${var.environment}-sample-endpoints"
    }
  })]

}
