variable "environment" {
  description = "Environment managed by this stack"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the Argo CD HTTPS ALB"
  type        = string
}

variable "argocd_domain" {
  description = "DNS hostname for the internal Argo CD ALB"
  type        = string

  validation {
    condition     = length(trimspace(var.argocd_domain)) > 0
    error_message = "argocd_domain must be a non-empty private DNS hostname."
  }
}

variable "argocd_chart_version" {
  description = "Pinned Argo CD Helm chart version"
  type        = string
  default     = "9.0.0"
}

variable "owner" {
  description = "Accountable team or owner used for cost and operations reporting"
  type        = string
  default     = "qzee-dev"
}

variable "cost_center" {
  description = "Finance-approved cost center code for AWS cost allocation"
  type        = string

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must be set to a non-empty finance-approved code."
  }
}

variable "project_name" {
  description = "Project identifier applied to AWS resource tags"
  type        = string
  default     = "fintech-platform"
}
