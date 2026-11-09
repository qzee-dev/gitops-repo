variable "aws_region" {
  description = "AWS region containing the existing dev EKS cluster and related resources"
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the existing dev EKS cluster"
  type    = string
}

variable "argocd_chart_version" {
  description = "Pinned Argo CD Helm chart version"
  type        = string
  default     = "9.0.0"
}

variable "keda_chart_version" {
  description = "Pinned KEDA Helm chart version"
  type        = string
  default     = "2.21.0"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for Argo CD"
  type    = string
  default = "argocd"
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

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for Argo CD HTTPS ALB"
  type        = string
}

variable "argocd_domain" {
  description = "DNS hostname for the internal Argo CD ALB"
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
