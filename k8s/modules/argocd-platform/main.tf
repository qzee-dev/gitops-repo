resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
      owner                          = var.owner
      "cost-center"                  = var.cost_center
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  create_namespace = false

  values = [
    templatefile("${path.module}/argocd-values.yaml.tftpl", {
      acm_certificate_arn = var.acm_certificate_arn
      argocd_domain       = var.argocd_domain
      cost_center         = var.cost_center
      environment         = var.environment
      owner               = var.owner
      project_name        = var.project_name
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
  ]
}
