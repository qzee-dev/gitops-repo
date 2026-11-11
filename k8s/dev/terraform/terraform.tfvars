aws_region    = "us-east-1"
environment   = "dev"
project_name  = "fintech-platform"
owner         = "qzee-dev"
app_namespace = "dev"

# Add-on and ingress selection. Set ingress values and secret variables before apply.
enable_pod_identity_agent              = true
enable_aws_load_balancer_controller    = true
enable_keda                            = true
enable_monitoring                      = true
enable_frontend                        = true
ingress_controller                     = "f5-nginx"
ingress_load_balancer_scheme           = "internal"
enable_cert_manager                    = true
enable_route53_dns01                   = true
enable_argocd                          = false

# Supply these real infrastructure/FinOps values before planning:
# cluster_name       = "<existing-dev-eks-cluster>"
# vpc_id             = "vpc-<id>"
# cost_center        = "<finance-approved-cost-center>"
