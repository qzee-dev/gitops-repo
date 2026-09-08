
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
}
