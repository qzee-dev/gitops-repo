resource "helm_release" "this" {
  name             = "${var.environment}-frontend"
  chart            = "${path.module}/../../ingress-platform/charts/frontend"
  namespace        = var.app_namespace
  create_namespace = true
  wait             = true

  values = [yamlencode({
    image    = var.image
    replicas = var.replicas
  })]
}