resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_chart_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  wait             = true
  timeout          = 600

}

resource "helm_release" "routes" {
  name             = "${var.environment}-envoy-routes"
  chart            = "${path.module}/../charts/routes"
  namespace        = "edge-gateway"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    controller   = "envoy"
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
    tlsEnabled = var.enable_tls
    issuer = {
      create       = var.enable_tls
      name         = "letsencrypt-dns01"
      server       = var.acme_server
      email        = var.acme_email
      region       = var.aws_region
      hostedZoneID = var.route53_zone_id
    }
    alb = {
      certificateArn = ""
      scheme         = var.load_balancer_scheme
      groupName      = "${var.environment}-sample-endpoints"
    }
  })]

  depends_on = [helm_release.envoy_gateway]
}
