variable "chart_version" {
  type = string
}

variable "environment" {
  type = string
}

variable "otel_collector_chart_version" {
  type    = string
  default = "0.117.0"
}

variable "tempo_chart_version" {
  type    = string
  default = "1.23.0"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}