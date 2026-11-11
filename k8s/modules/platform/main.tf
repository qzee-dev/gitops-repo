resource "terraform_data" "validate_config" {
  input = var.environment

  lifecycle {
    precondition {
      condition     = !var.enable_route53_dns01 || (var.enable_cert_manager && length(trimspace(var.route53_zone_id)) > 0 && length(trimspace(var.acme_email)) > 0)
      error_message = "Route 53 DNS-01 requires cert-manager, route53_zone_id, and acme_email."
    }

    precondition {
      condition     = var.ingress_controller == "none" || length(trimspace(var.ingress_domain_suffix)) > 0
      error_message = "Set ingress_domain_suffix when an ingress controller is selected."
    }

    precondition {
      condition     = var.ingress_controller != "alb" || length(trimspace(var.ingress_alb_certificate_arn)) > 0
      error_message = "ALB ingress requires an ACM certificate ARN."
    }

    precondition {
      condition     = !var.enable_monitoring || length(var.grafana_admin_password) >= 16
      error_message = "Monitoring requires a Grafana administrator password of at least 16 characters."
    }

    precondition {
      condition     = !var.enable_argocd || (length(trimspace(var.argocd_domain)) > 0 && length(trimspace(var.argocd_acm_certificate_arn)) > 0)
      error_message = "Argo CD requires a domain and ACM certificate ARN."
    }
  }
}

module "pod_identity_agent" {
  count  = local.needs_pod_identity_agent ? 1 : 0
  source = "../addons/pod-identity-agent"

  cluster_name = var.cluster_name
  tags         = local.common_tags

  depends_on = [terraform_data.validate_config]
}

module "aws_load_balancer_controller" {
  count  = local.needs_aws_load_balancer_controller ? 1 : 0
  source = "../addons/aws-load-balancer-controller"

  cluster_name = var.cluster_name
  aws_region   = var.aws_region
  vpc_id       = var.vpc_id
  chart_version = var.aws_load_balancer_controller_chart_version
  tags          = local.common_tags

  depends_on = [terraform_data.validate_config, module.pod_identity_agent]
}

module "keda" {
  count  = var.enable_keda ? 1 : 0
  source = "../addons/keda"

  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  project_name = var.project_name
  chart_version = var.keda_chart_version

  depends_on = [terraform_data.validate_config]
}

module "cert_manager" {
  count  = var.enable_cert_manager ? 1 : 0
  source = "../addons/cert-manager"

  environment         = var.environment
  cluster_name        = var.cluster_name
  chart_version       = var.cert_manager_chart_version
  enable_route53_dns01 = var.enable_route53_dns01
  route53_zone_id     = var.route53_zone_id
  tags                = local.common_tags

  depends_on = [terraform_data.validate_config, module.pod_identity_agent]
}

module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "../addons/monitoring"

  chart_version          = var.kube_prometheus_stack_chart_version
  grafana_admin_password = var.grafana_admin_password

  depends_on = [terraform_data.validate_config]
}

module "frontend" {
  count  = var.enable_frontend ? 1 : 0
  source = "../addons/frontend"

  environment  = var.environment
  app_namespace = var.app_namespace
  image         = var.frontend_image
  replicas      = var.frontend_replicas

  depends_on = [terraform_data.validate_config]
}

module "argocd" {
  count  = var.enable_argocd ? 1 : 0
  source = "../argocd-platform"

  environment         = var.environment
  acm_certificate_arn = var.argocd_acm_certificate_arn
  argocd_domain       = var.argocd_domain
  owner               = var.owner
  cost_center         = var.cost_center
  project_name        = var.project_name

  depends_on = [terraform_data.validate_config, module.aws_load_balancer_controller]
}

module "ingress_envoy" {
  count  = var.ingress_controller == "envoy" ? 1 : 0
  source = "../envoy-gateway"

  environment          = var.environment
  cluster_name         = var.cluster_name
  aws_region           = var.aws_region
  app_namespace        = var.app_namespace
  domain_suffix        = var.ingress_domain_suffix
  load_balancer_scheme = var.ingress_load_balancer_scheme
  route53_zone_id      = var.route53_zone_id
  acme_email           = var.acme_email
  acme_server          = var.acme_server
  enable_tls           = var.enable_cert_manager && var.enable_route53_dns01
  frontend_enabled     = var.enable_frontend
  monitoring_enabled   = var.enable_monitoring

  depends_on = [terraform_data.validate_config, module.aws_load_balancer_controller, module.cert_manager, module.frontend, module.monitoring]
}

module "ingress_nginx" {
  count  = var.ingress_controller == "nginx" ? 1 : 0
  source = "../ingress-nginx"

  environment          = var.environment
  cluster_name         = var.cluster_name
  aws_region           = var.aws_region
  app_namespace        = var.app_namespace
  domain_suffix        = var.ingress_domain_suffix
  load_balancer_scheme = var.ingress_load_balancer_scheme
  route53_zone_id      = var.route53_zone_id
  acme_email           = var.acme_email
  acme_server          = var.acme_server
  enable_tls           = var.enable_cert_manager && var.enable_route53_dns01
  frontend_enabled     = var.enable_frontend
  monitoring_enabled   = var.enable_monitoring

  depends_on = [terraform_data.validate_config, module.aws_load_balancer_controller, module.cert_manager, module.frontend, module.monitoring]
}

module "ingress_f5_nginx" {
  count  = var.ingress_controller == "f5-nginx" ? 1 : 0
  source = "../f5-nginx-ingress"

  environment          = var.environment
  cluster_name         = var.cluster_name
  aws_region           = var.aws_region
  app_namespace        = var.app_namespace
  domain_suffix        = var.ingress_domain_suffix
  load_balancer_scheme = var.ingress_load_balancer_scheme
  route53_zone_id      = var.route53_zone_id
  acme_email           = var.acme_email
  acme_server          = var.acme_server
  enable_tls           = var.enable_cert_manager && var.enable_route53_dns01
  frontend_enabled     = var.enable_frontend
  monitoring_enabled   = var.enable_monitoring

  depends_on = [terraform_data.validate_config, module.aws_load_balancer_controller, module.cert_manager, module.frontend, module.monitoring]
}

module "ingress_alb" {
  count  = var.ingress_controller == "alb" ? 1 : 0
  source = "../aws-alb-controller"

  environment        = var.environment
  app_namespace      = var.app_namespace
  domain_suffix      = var.ingress_domain_suffix
  certificate_arn    = var.ingress_alb_certificate_arn
  alb_scheme         = var.ingress_load_balancer_scheme
  frontend_enabled   = var.enable_frontend
  monitoring_enabled = var.enable_monitoring

  depends_on = [terraform_data.validate_config, module.aws_load_balancer_controller, module.frontend, module.monitoring]
}

output "enabled_addons" {
  value = compact([
    local.needs_pod_identity_agent ? "pod-identity-agent" : "",
    local.needs_aws_load_balancer_controller ? "aws-load-balancer-controller" : "",
    var.enable_keda ? "keda" : "",
    var.enable_cert_manager ? "cert-manager" : "",
    var.enable_monitoring ? "monitoring" : "",
    var.enable_frontend ? "frontend" : "",
    var.ingress_controller != "none" ? var.ingress_controller : "",
    var.enable_argocd ? "argocd" : "",
  ])
}