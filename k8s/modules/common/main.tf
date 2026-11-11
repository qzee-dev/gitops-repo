locals {
  hostnames = {
    frontend   = "app.${var.domain_suffix}"
    grafana    = "grafana.${var.domain_suffix}"
    prometheus = "prometheus.${var.domain_suffix}"
  }
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

resource "aws_iam_role" "cert_manager_route53" {
  count = var.manage_route53_pod_identity ? 1 : 0

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
}

resource "aws_iam_role_policy" "cert_manager_route53" {
  count = var.manage_route53_pod_identity ? 1 : 0

  name = "${var.cluster_name}-${var.environment}-cert-manager-route53"
  role = aws_iam_role.cert_manager_route53[0].id
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

resource "aws_eks_pod_identity_association" "cert_manager" {
  count = var.manage_route53_pod_identity ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = aws_iam_role.cert_manager_route53[0].arn
}

resource "helm_release" "cert_manager" {
  count = var.manage_cert_manager ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true

  values = [
    yamlencode({
      crds = { enabled = true }
      serviceAccount = {
        create = true
        name   = "cert-manager"
      }
      extraArgs = ["--cluster-issuer-ambient-credentials"]
    })
  ]

  depends_on = [aws_eks_pod_identity_association.cert_manager]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prometheus_stack_chart_version
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled = true
          size    = "10Gi"
        }
        ingress = { enabled = false }
      }
      prometheus = {
        ingress = { enabled = false }
        prometheusSpec = {
          retention = "15d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = "20Gi" }
                }
              }
            }
          }
        }
      }
      alertmanager = {
        enabled = true
      }
    })
  ]

  lifecycle {
    precondition {
      condition     = length(var.grafana_admin_password) >= 16
      error_message = "Set grafana_admin_password to a password with at least 16 characters."
    }
  }
}

resource "helm_release" "frontend" {
  name             = "${var.environment}-frontend"
  chart            = "${path.module}/../ingress-platform/charts/frontend"
  namespace        = var.app_namespace
  create_namespace = true
  wait             = true

  values = [
    yamlencode({
      image    = var.frontend_image
      replicas = var.frontend_replicas
    })
  ]
}

output "hostnames" {
  value = local.hostnames
}
