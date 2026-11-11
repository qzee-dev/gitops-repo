variable "environment" {
  description = "Environment name used for the stack"
  type        = string
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region containing the cluster"
  type        = string
}

variable "app_namespace" {
  description = "Namespace for the sample frontend"
  type        = string
}

variable "domain_suffix" {
  description = "DNS suffix used for routes"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "frontend_image" {
  description = "Frontend image to deploy"
  type        = string
  default     = "nginx:1.29.2-alpine"
}

variable "frontend_replicas" {
  description = "Number of frontend replicas"
  type        = number
  default     = 2
}

variable "route53_zone_id" {
  description = "Hosted zone ID for DNS-01 validation"
  type        = string
  default     = ""
}

variable "acme_email" {
  description = "Operations email used by cert-manager"
  type        = string
  default     = ""
}

variable "acme_server" {
  description = "ACME server URL"
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "manage_cert_manager" {
  description = "Whether cert-manager should be created by this stack"
  type        = bool
  default     = true
}

variable "manage_route53_pod_identity" {
  description = "Whether to create Route53 Pod Identity"
  type        = bool
  default     = true
}

variable "cert_manager_chart_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "1.17.2"
}

variable "kube_prometheus_stack_chart_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "93.1.1"
}
