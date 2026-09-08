
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name        = "${var.cluster_name}-pod-identity-agent"
    ManagedBy   = "Terraform"
    Addon       = "eks-pod-identity-agent"
  }
}
