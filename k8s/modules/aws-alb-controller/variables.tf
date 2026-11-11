variable "environment" {
  type = string
}

variable "app_namespace" {
  type = string
}

variable "domain_suffix" {
  type = string
}

variable "grafana_hostname" {
  type = string
}

variable "prometheus_hostname" {
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

variable "frontend_enabled" {
  type = bool
}

variable "monitoring_enabled" {
  type = bool
}

variable "logging_enabled" {
  type = bool
}

variable "kibana_hostname" {
  type = string
}
