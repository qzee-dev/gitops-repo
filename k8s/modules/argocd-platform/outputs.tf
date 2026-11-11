output "argocd_url" {
  description = "Argo CD URL; create a DNS record for the configured hostname"
  value       = "https://${var.argocd_domain}"
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

