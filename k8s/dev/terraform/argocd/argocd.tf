
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

  version = var.argocd_chart_version

  create_namespace = false

  values = [
    templatefile(
      "${path.module}/argocd/values.yaml",
      {
        acm_certificate_arn = var.acm_certificate_arn
      }
    )
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller
  ]
}

