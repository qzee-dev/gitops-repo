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

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_chart_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  wait             = true
  timeout          = 600

  depends_on = [module.common.helm_release.cert_manager]
}

resource "helm_release" "routes" {
  name             = "${var.environment}-envoy-routes"
  chart            = "${path.module}/../ingress-platform/charts/routes"
  namespace        = "edge-gateway"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    controller   = "envoy"
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
    helm_release.envoy_gateway,
    module.common.helm_release.kube_prometheus_stack,
    module.common.helm_release.frontend,
  ]
}
