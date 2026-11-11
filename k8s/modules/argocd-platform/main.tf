resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name      = "${var.cluster_name}-pod-identity-agent"
    Component = "pod-identity-agent"
    Addon     = "eks-pod-identity-agent"
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.cluster_name}-AWSLoadBalancerControllerPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam-policy.json")
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name      = "${var.cluster_name}-aws-load-balancer-controller"
    Component = "aws-load-balancer-controller"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  tags = merge(local.common_tags, {
    Component = "aws-load-balancer-controller"
  })

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [
    aws_eks_pod_identity_association.aws_load_balancer_controller,
  ]
}

resource "kubernetes_namespace" "keda" {
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

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_chart_version
  namespace  = kubernetes_namespace.keda.metadata[0].name

  create_namespace = false

  set {
    name  = "crds.install"
    value = "true"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    kubernetes_namespace.keda,
  ]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
      owner                          = var.owner
      "cost-center"                  = var.cost_center
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  create_namespace = false

  values = [
    templatefile("${path.module}/argocd-values.yaml.tftpl", {
      acm_certificate_arn = var.acm_certificate_arn
      argocd_domain       = var.argocd_domain
      cost_center         = var.cost_center
      environment         = var.environment
      owner               = var.owner
      project_name        = var.project_name
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller,
    helm_release.keda,
  ]
}
