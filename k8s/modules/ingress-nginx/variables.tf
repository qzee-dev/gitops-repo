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

variable "load_balancer_scheme" {
  type = string
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

variable "enable_tls" {
  type = bool
}

variable "frontend_enabled" {
  type = bool
}

variable "monitoring_enabled" {
  type = bool
}

variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.12.1"
}

