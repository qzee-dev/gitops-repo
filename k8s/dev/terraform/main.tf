resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
}
