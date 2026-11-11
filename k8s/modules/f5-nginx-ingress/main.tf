resource "helm_release" "f5_nginx_ingress" {
  name             = "f5-nginx-ingress"
  repository       = "https://helm.nginx.com/stable"
  chart            = "nginx-ingress"
  version          = var.f5_nginx_ingress_chart_version
  namespace        = "f5-nginx-ingress"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    controller = {
      ingressClass = {
        create  = true
        name    = "f5-nginx"
        enabled = true
        default = false
      }
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = var.load_balancer_scheme
        }
      }
    }
  })]

}

resource "helm_release" "routes" {
  name             = "${var.environment}-f5-routes"
  chart            = "${path.module}/../charts/routes"
  namespace        = "edge-gateway"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    controller   = "f5-nginx"
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

  depends_on = [helm_release.f5_nginx_ingress]
}
