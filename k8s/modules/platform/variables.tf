variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "owner" {
  type    = string
  default = "qzee-dev"
}

variable "cost_center" {
  type = string
}

variable "project_name" {
  type    = string
  default = "fintech-platform"
}

variable "app_namespace" {
  type = string
}

variable "enable_pod_identity_agent" {
  type    = bool
  default = false
}

variable "enable_aws_load_balancer_controller" {
  type    = bool
  default = false
}

variable "aws_load_balancer_controller_chart_version" {
  type    = string
  default = "1.13.4"
}

variable "enable_keda" {
  type    = bool
  default = false
}

variable "keda_chart_version" {
  type    = string
  default = "2.21.0"
}

variable "enable_cert_manager" {
  type    = bool
  default = false
}

variable "cert_manager_chart_version" {
  type    = string
  default = "1.17.2"
}

variable "enable_route53_dns01" {
  type    = bool
  default = false
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

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "kube_prometheus_stack_chart_version" {
  type    = string
  default = "93.1.1"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "enable_efk" {
  type    = bool
  default = false
}

variable "eck_operator_chart_version" {
  type    = string
  default = "3.5.0"
}

variable "elasticsearch_version" {
  type    = string
  default = "9.5.6"
}

variable "elasticsearch_node_count" {
  type    = number
  default = 1
}

variable "elasticsearch_storage_size" {
  type    = string
  default = "20Gi"
}

variable "elasticsearch_storage_class" {
  type    = string
  default = ""
}

variable "elasticsearch_cpu" {
  type    = string
  default = "2"
}

variable "elasticsearch_memory" {
  type    = string
  default = "4Gi"
}

variable "kibana_cpu" {
  type    = string
  default = "500m"
}

variable "kibana_memory" {
  type    = string
  default = "1Gi"
}

variable "fluent_bit_chart_version" {
  type    = string
  default = "0.58.3"
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "kibana_hostname" {
  type    = string
  default = ""
}

variable "enable_frontend" {
  type    = bool
  default = false
}

variable "frontend_image" {
  type    = string
  default = "nginx:1.29.2-alpine"
}

variable "frontend_replicas" {
  type    = number
  default = 2
}

variable "ingress_controller" {
  type    = string
  default = "none"

  validation {
    condition     = contains(["none", "envoy", "nginx", "f5-nginx", "alb"], var.ingress_controller)
    error_message = "ingress_controller must be none, envoy, nginx, f5-nginx, or alb."
  }
}

variable "ingress_domain_suffix" {
  type    = string
  default = ""
}

variable "grafana_hostname" {
  type    = string
  default = ""
}

variable "prometheus_hostname" {
  type    = string
  default = ""
}

variable "ingress_load_balancer_scheme" {
  type    = string
  default = "internal"

  validation {
    condition     = contains(["internal", "internet-facing"], var.ingress_load_balancer_scheme)
    error_message = "ingress_load_balancer_scheme must be internal or internet-facing."
  }
}

variable "ingress_alb_certificate_arn" {
  type    = string
  default = ""
}

variable "enable_argocd" {
  type    = bool
  default = false
}

variable "argocd_domain" {
  type    = string
  default = ""
}

variable "argocd_acm_certificate_arn" {
  type    = string
  default = ""
}
