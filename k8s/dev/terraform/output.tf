output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "cluster_name" {
  value = data.aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = data.aws_eks_cluster.this.endpoint
}


output "pod_identity_agent_status" {
  value = aws_eks_addon.pod_identity_agent.status
}

output "pod_identity_agent_version" {
  value = aws_eks_addon.pod_identity_agent.addon_version
}

