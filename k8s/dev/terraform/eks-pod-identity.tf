
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  tags = {
    Name = "${var.cluster_name}-pod-identity-agent"
  }
}
