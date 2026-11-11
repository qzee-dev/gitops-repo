output "cert_manager_route53_role_arn" {
  description = "EKS Pod Identity role used by cert-manager for DNS-01"
  value       = aws_iam_role.cert_manager_route53.arn
}
