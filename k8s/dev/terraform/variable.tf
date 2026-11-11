variable "aws_region" {
  description = "AWS region containing the existing dev EKS cluster and related resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the existing dev EKS cluster"
  type        = string
}

variable "keda_chart_version" {
  description = "Pinned KEDA Helm chart version"
  type        = string
  default     = "2.21.0"
}

variable "app_namespace" {
  description = "Namespace reserved for fintech application workloads"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID of the existing dev EKS cluster"
  type        = string
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

variable "environment" {
  description = "Deployment environment represented by this stack"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project identifier applied to AWS resource tags"
  type        = string
  default     = "fintech-platform"
}

variable "ingress_platform_enabled" {
  description = "Enable the reusable ingress, DNS-01, monitoring, and sample frontend module"
  type        = bool
  default     = false
}

variable "ingress_controller" {
  description = "Controller for this environment: envoy, nginx, alb, or f5-nginx"
  type        = string
  default     = "f5-nginx"

  validation {
    condition     = contains(["envoy", "nginx", "alb", "f5-nginx"], var.ingress_controller)
    error_message = "ingress_controller must be envoy, nginx, alb, or f5-nginx."
  }
}

variable "ingress_domain_suffix" {
  description = "DNS suffix for ingress endpoints, such as dev.example.com"
  type        = string
  default     = ""
}

variable "ingress_route53_zone_id" {
  description = "Public Route 53 hosted zone ID used for DNS-01"
  type        = string
  default     = ""
}

variable "ingress_acme_email" {
  description = "Operations email address registered with ACME"
  type        = string
  default     = ""
}

variable "ingress_acme_server" {
  description = "ACME directory URL; defaults to Let's Encrypt staging"
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "ingress_alb_certificate_arn" {
  description = "ACM certificate ARN covering the sample endpoints when using ALB"
  type        = string
  default     = ""
}

variable "ingress_alb_scheme" {
  description = "ALB scheme when using the ALB controller"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["internal", "internet-facing"], var.ingress_alb_scheme)
    error_message = "ingress_alb_scheme must be internal or internet-facing."
  }
}

variable "ingress_manage_cert_manager" {
  description = "Install cert-manager and manage the DNS-01 ClusterIssuer"
  type        = bool
  default     = true
}

variable "ingress_manage_route53_pod_identity" {
  description = "Create the cert-manager Route 53 IAM role and EKS Pod Identity association"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana administrator password; provide through TF_VAR_grafana_admin_password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "frontend_image" {
  description = "Container image used by the sample frontend"
  type        = string
  default     = "nginx:1.29.2-alpine"
}

variable "frontend_replicas" {
  description = "Number of sample frontend replicas"
  type        = number
  default     = 2
}
