resource "kubernetes_namespace" "this" {
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

resource "helm_release" "this" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  set {
    name  = "crds.install"
    value = "true"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [kubernetes_namespace.this]
}