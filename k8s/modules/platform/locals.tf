locals {
  common_tags = {
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Environment = var.environment
    CostCenter  = var.cost_center
    Project     = var.project_name
  }

  needs_aws_load_balancer_controller = var.enable_aws_load_balancer_controller || var.enable_argocd || var.ingress_controller != "none"
  needs_pod_identity_agent           = var.enable_pod_identity_agent || local.needs_aws_load_balancer_controller || var.enable_route53_dns01
}