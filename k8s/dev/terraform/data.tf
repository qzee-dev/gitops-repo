
# Equivalent to:
# aws sts get-caller-identity
data "aws_caller_identity" "current" {}

# Get information about the existing EKS cluster
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Get authentication token for the EKS cluster
data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}
