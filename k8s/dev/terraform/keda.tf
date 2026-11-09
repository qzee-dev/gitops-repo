resource "kubernetes_namespace" "keda" {
  metadata {
    name = "keda"

    labels = {
      "app.kubernetes.io/part-of"    = var.project_name
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
      owner                          = var.owner
      "cost-center"                  = var.cost_center
    }
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_chart_version
  namespace  = kubernetes_namespace.keda.metadata[0].name

  create_namespace = false

  set {
    name  = "crds.install"
    value = "true"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    kubernetes_namespace.keda,
  ]
}
