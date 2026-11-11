output "argocd_url" {
  description = "Argo CD URL; create a DNS record for the configured hostname"
  value       = "https://${var.argocd_domain}"
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}
