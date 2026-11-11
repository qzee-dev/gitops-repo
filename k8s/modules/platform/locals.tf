locals {
  common_tags = {
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Environment = var.environment
    CostCenter  = var.cost_center
    Project     = var.project_name
  }

  grafana_hostname    = var.grafana_hostname != "" ? var.grafana_hostname : "grafana.${var.ingress_domain_suffix}"
  prometheus_hostname = var.prometheus_hostname != "" ? var.prometheus_hostname : "prometheus.${var.ingress_domain_suffix}"
  kibana_hostname     = var.kibana_hostname != "" ? var.kibana_hostname : "kibana.${var.ingress_domain_suffix}"

  needs_aws_load_balancer_controller = var.enable_aws_load_balancer_controller || var.enable_argocd || var.ingress_controller != "none"
  needs_pod_identity_agent           = var.enable_pod_identity_agent || local.needs_aws_load_balancer_controller || var.enable_route53_dns01
}
