variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "app_namespace" {
  type = string
}

variable "domain_suffix" {
  type = string
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "alb_scheme" {
  type    = string
  default = "internal"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "frontend_image" {
  type    = string
  default = "nginx:1.29.2-alpine"
}

variable "frontend_replicas" {
  type    = number
  default = 2
}

variable "manage_cert_manager" {
  type    = bool
  default = true
}

variable "manage_route53_pod_identity" {
  type    = bool
  default = true
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

variable "acme_email" {
  type    = string
  default = ""
}

variable "acme_server" {
  type    = string
  default = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "cert_manager_chart_version" {
  type    = string
  default = "1.17.2"
}

variable "kube_prometheus_stack_chart_version" {
  type    = string
  default = "93.1.1"
}
