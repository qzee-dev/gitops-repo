locals {
  ecr_repositories = {
    for service in var.microservices :
    service => "${var.repository_prefix}/${service}"
  }

  common_tags = {
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Environment = var.environment
    CostCenter  = var.cost_center
    Project     = var.project_name
  }
}
