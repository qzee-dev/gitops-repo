moved {
  from = aws_eks_addon.pod_identity_agent
  to   = module.platform.module.pod_identity_agent[0].aws_eks_addon.this
}

moved {
  from = aws_iam_policy.aws_load_balancer_controller
  to   = module.platform.module.aws_load_balancer_controller[0].aws_iam_policy.this
}

moved {
  from = aws_iam_role.aws_load_balancer_controller
  to   = module.platform.module.aws_load_balancer_controller[0].aws_iam_role.this
}

moved {
  from = aws_iam_role_policy_attachment.aws_load_balancer_controller
  to   = module.platform.module.aws_load_balancer_controller[0].aws_iam_role_policy_attachment.this
}

moved {
  from = aws_eks_pod_identity_association.aws_load_balancer_controller
  to   = module.platform.module.aws_load_balancer_controller[0].aws_eks_pod_identity_association.this
}

moved {
  from = helm_release.aws_load_balancer_controller
  to   = module.platform.module.aws_load_balancer_controller[0].helm_release.this
}

moved {
  from = kubernetes_namespace.keda
  to   = module.platform.module.keda[0].kubernetes_namespace.this
}

moved {
  from = helm_release.keda
  to   = module.platform.module.keda[0].helm_release.this
}