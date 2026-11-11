# Existing dev infrastructure and required FinOps value.
aws_region   = "us-east-1"
cluster_name = "REPLACE_WITH_DEV_EKS_CLUSTER_NAME"
vpc_id       = "REPLACE_WITH_DEV_VPC_ID"
cost_center  = "REPLACE_WITH_APPROVED_COST_CENTER"

# Environment identity and resource ownership.
environment   = "dev"
owner         = "qzee-dev"
project_name  = "fintech-platform"
app_namespace = "dev"

# Add-ons. The AWS Load Balancer Controller and Pod Identity Agent are also
# required automatically by the selected ingress and Route 53 DNS-01 setup.
enable_pod_identity_agent                  = true
enable_aws_load_balancer_controller        = true
aws_load_balancer_controller_chart_version = "1.13.4"
enable_keda                                = true
keda_chart_version                         = "2.21.0"
enable_cert_manager                        = true
cert_manager_chart_version                 = "1.17.2"
enable_route53_dns01                       = true
route53_zone_id                            = "REPLACE_WITH_DEV_ROUTE53_ZONE_ID"
acme_email                                 = "REPLACE_WITH_OPERATIONS_EMAIL"
acme_server                                = "https://acme-staging-v02.api.letsencrypt.org/directory"
enable_monitoring                          = true
kube_prometheus_stack_chart_version        = "93.1.1"
enable_efk                                 = true
eck_operator_chart_version                 = "3.5.0"
elasticsearch_version                      = "9.5.6"
elasticsearch_node_count                   = 1
elasticsearch_storage_size                 = "20Gi"
elasticsearch_storage_class                = ""
elasticsearch_cpu                          = "2"
elasticsearch_memory                       = "4Gi"
kibana_cpu                                 = "500m"
kibana_memory                              = "1Gi"
fluent_bit_chart_version                   = "0.58.3"
log_retention_days                         = 14
enable_frontend                            = true
frontend_image                             = "nginx:1.29.2-alpine"
frontend_replicas                          = 2

# Dev ingress.
ingress_controller           = "f5-nginx"
ingress_domain_suffix        = "REPLACE_WITH_DEV_DNS_SUFFIX"
grafana_hostname             = "REPLACE_WITH_DEV_GRAFANA_HOSTNAME"
prometheus_hostname          = "REPLACE_WITH_DEV_PROMETHEUS_HOSTNAME"
kibana_hostname              = "REPLACE_WITH_DEV_KIBANA_HOSTNAME"
ingress_load_balancer_scheme = "internal"
ingress_alb_certificate_arn  = ""

# Dev application deployments use the manual release workflow, not Argo CD.
enable_argocd              = false
argocd_domain              = ""
argocd_acm_certificate_arn = ""

# This file is tracked. Do not put secrets here. Set the Grafana password in
# the runner environment or secret store as TF_VAR_grafana_admin_password.
