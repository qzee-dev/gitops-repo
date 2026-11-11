module "common" {
  source = "../common"

  environment                         = var.environment
  cluster_name                        = var.cluster_name
  aws_region                          = var.aws_region
  app_namespace                       = var.app_namespace
  domain_suffix                       = var.domain_suffix
  grafana_admin_password              = var.grafana_admin_password
  frontend_image                      = var.frontend_image
  frontend_replicas                   = var.frontend_replicas
  route53_zone_id                     = var.route53_zone_id
  acme_email                          = var.acme_email
  acme_server                         = var.acme_server
  manage_cert_manager                 = var.manage_cert_manager
  manage_route53_pod_identity         = var.manage_route53_pod_identity
  cert_manager_chart_version          = var.cert_manager_chart_version
  kube_prometheus_stack_chart_version = var.kube_prometheus_stack_chart_version
}

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
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
        }
      }
    }
  })]

  depends_on = [module.common.helm_release.cert_manager]
}

resource "helm_release" "routes" {
  name             = "${var.environment}-f5-routes"
  chart            = "${path.module}/../ingress-platform/charts/routes"
  namespace        = "edge-gateway"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    controller   = "f5-nginx"
    environment  = var.environment
    appNamespace = var.app_namespace
    domainSuffix = var.domain_suffix
    hostnames    = module.common.hostnames
    issuer = {
      create       = var.manage_cert_manager
      name         = "letsencrypt-dns01"
      server       = var.acme_server
      email        = var.acme_email
      region       = var.aws_region
      hostedZoneID = var.route53_zone_id
    }
    alb = {
      certificateArn = ""
      scheme         = "internal"
      groupName      = "${var.environment}-sample-endpoints"
    }
  })]

  depends_on = [
    helm_release.f5_nginx_ingress,
    module.common.helm_release.kube_prometheus_stack,
    module.common.helm_release.frontend,
  ]
}
