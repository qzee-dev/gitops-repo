aws_region           = "us-east-1"
environment          = "dev"
project_name         = "fintech-platform"
owner                = "qzee-dev"
argocd_namespace     = "argocd"
app_namespace        = "dev"
argocd_chart_version = "9.0.0"

# Supply these real infrastructure/FinOps values before planning:
# cluster_name       = "<existing-dev-eks-cluster>"
# vpc_id             = "vpc-<id>"
# acm_certificate_arn = "arn:aws:acm:us-east-1:<account>:certificate/<id>"
# argocd_domain       = "argocd.dev.example.com"
# cost_center        = "<finance-approved-cost-center>"

