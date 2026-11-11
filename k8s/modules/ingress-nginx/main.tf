resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    controller = {
      ingressClass             = "nginx"
      watchIngressWithoutClass = false
      ingressClassResource = {
        name    = "nginx"
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
  name             = "${var.environment}-nginx-routes"
  chart            = "${path.module}/../charts/routes"
  namespace        = "edge-gateway"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    controller   = "nginx"
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

  depends_on = [helm_release.ingress_nginx]
}
