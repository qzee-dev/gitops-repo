
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace

    labels = {
      "app.kubernetes.io/part-of" = var.project_name
      "app.kubernetes.io/managed-by" = "terraform"
      environment = var.environment
      owner       = var.owner
      "cost-center" = var.cost_center
    }
  }
}
