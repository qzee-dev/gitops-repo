variable "aws_region" {
  description = "AWS region containing the EKS cluster and Route 53 hosted zone"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID where cert-manager may create DNS-01 records"
  type        = string

  validation {
    condition     = length(trimspace(var.route53_zone_id)) > 0
    error_message = "route53_zone_id must be set to the hosted zone used for DNS-01."
  }
}

variable "ingress_nginx_chart_version" {
  description = "Pinned ingress-nginx Helm chart version"
  type        = string
  default     = "4.12.1"
}

variable "cert_manager_chart_version" {
  description = "Pinned cert-manager Helm chart version"
  type        = string
  default     = "1.17.2"
}
