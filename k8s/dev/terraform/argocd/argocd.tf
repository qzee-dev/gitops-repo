
################################################################################
# Argo CD
################################################################################

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}


resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  # Pin the chart version.
  version = var.argocd_chart_version

  # Namespace is managed separately by Terraform.
  create_namespace = false

  depends_on = [
    kubernetes_namespace.argocd
  ]
}
