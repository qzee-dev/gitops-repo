locals {
  common_tags = {
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Environment = var.environment
    CostCenter  = var.cost_center
    Project     = var.project_name
  }
}
