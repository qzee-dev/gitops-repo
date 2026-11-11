output "frontend_url" {
  description = "Frontend endpoint hostname"
  value       = var.enabled ? "https://app.${var.domain_suffix}" : null
}

output "grafana_url" {
  description = "Grafana endpoint hostname"
  value       = var.enabled ? "https://grafana.${var.domain_suffix}" : null
}

output "prometheus_url" {
  description = "Prometheus endpoint hostname"
  value       = var.enabled ? "https://prometheus.${var.domain_suffix}" : null
}

output "cert_manager_route53_role_arn" {
  description = "Route 53 Pod Identity role ARN, when managed by this module"
  value       = try(aws_iam_role.cert_manager_route53[0].arn, null)
}
