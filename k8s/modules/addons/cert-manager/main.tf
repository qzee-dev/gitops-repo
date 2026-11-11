data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

resource "aws_iam_role" "route53" {
  count = var.enable_route53_dns01 ? 1 : 0

  name = "${var.cluster_name}-${var.environment}-cert-manager-route53"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          "aws:SourceArn" = data.aws_eks_cluster.this.arn
        }
      }
    }]
  })

  tags = merge(var.tags, { Component = "cert-manager" })
}

resource "aws_iam_role_policy" "route53" {
  count = var.enable_route53_dns01 ? 1 : 0

  name = "${var.cluster_name}-${var.environment}-cert-manager-route53"
  role = aws_iam_role.route53[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
        Condition = {
          "ForAllValues:StringEquals" = {
            "route53:ChangeResourceRecordSetsRecordTypes" = ["TXT"]
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = "arn:aws:route53:::change/*"
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "route53" {
  count = var.enable_route53_dns01 ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = aws_iam_role.route53[0].arn
}

resource "helm_release" "this" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_version
  namespace        = "cert-manager"
  create_namespace = true

  values = [yamlencode({
    crds = { enabled = true }
    serviceAccount = {
      create = true
      name   = "cert-manager"
    }
    extraArgs = var.enable_route53_dns01 ? ["--cluster-issuer-ambient-credentials"] : []
  })]

  depends_on = [aws_eks_pod_identity_association.route53]
}