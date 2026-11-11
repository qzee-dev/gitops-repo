resource "aws_iam_role" "cert_manager_route53" {
  name = "${var.cluster_name}-cert-manager-route53"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
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
  name = "${var.cluster_name}-cert-manager-route53"
  role = aws_iam_role.cert_manager_route53.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
        Condition = {
          "ForAllValues:StringEquals" = {
            "route53:ChangeResourceRecordSetsRecordTypes" = ["TXT"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListResourceRecordSets",
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange",
        ]
        Resource = "arn:aws:route53:::change/*"
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "cert_manager" {
  cluster_name    = var.cluster_name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = aws_iam_role.cert_manager_route53.arn
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        ingressClass             = "nginx"
        watchIngressWithoutClass = false
        ingressClassResource = {
          name    = "nginx"
          enabled = true
          default = false
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
          }
        }
      }
    })
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
      serviceAccount = {
        create = true
        name   = "cert-manager"
      }
      extraArgs = [
        "--cluster-issuer-ambient-credentials",
      ]
    })
  ]

  depends_on = [
    aws_eks_pod_identity_association.cert_manager,
  ]
}
