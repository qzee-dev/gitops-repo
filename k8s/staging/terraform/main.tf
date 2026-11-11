module "platform" {
	source = "../../modules/platform"

	environment   = var.environment
	cluster_name  = var.cluster_name
	aws_region    = var.aws_region
	vpc_id        = var.vpc_id
	owner         = var.owner
	cost_center   = var.cost_center
	project_name  = var.project_name
	app_namespace = var.app_namespace

	enable_pod_identity_agent                  = var.enable_pod_identity_agent
	enable_aws_load_balancer_controller        = var.enable_aws_load_balancer_controller
	aws_load_balancer_controller_chart_version = var.aws_load_balancer_controller_chart_version
	enable_keda                                = var.enable_keda
	keda_chart_version                         = var.keda_chart_version
	enable_cert_manager                        = var.enable_cert_manager
	cert_manager_chart_version                 = var.cert_manager_chart_version
	enable_route53_dns01                       = var.enable_route53_dns01
	route53_zone_id                            = var.route53_zone_id
	acme_email                                 = var.acme_email
	acme_server                                = var.acme_server
	enable_monitoring                          = var.enable_monitoring
	kube_prometheus_stack_chart_version        = var.kube_prometheus_stack_chart_version
	grafana_admin_password                     = var.grafana_admin_password
	enable_frontend                            = var.enable_frontend
	frontend_image                             = var.frontend_image
	frontend_replicas                          = var.frontend_replicas

	ingress_controller          = var.ingress_controller
	ingress_domain_suffix        = var.ingress_domain_suffix
	ingress_load_balancer_scheme = var.ingress_load_balancer_scheme
	ingress_alb_certificate_arn  = var.ingress_alb_certificate_arn

	enable_argocd              = var.enable_argocd
	argocd_domain              = var.argocd_domain
	argocd_acm_certificate_arn = var.argocd_acm_certificate_arn
}

output "enabled_addons" {
	value = module.platform.enabled_addons
}
