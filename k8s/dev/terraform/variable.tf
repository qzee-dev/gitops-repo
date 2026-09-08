variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type    = string
  default = "my-eks-cluster"
}

variable "argocd_chart_version" {
  description = "Pinned Argo CD Helm chart version"
  type        = string
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for Argo CD"
  type    = string
  default = "argocd"
}

variable "app_namespace" {
  type    = string
  default = "myapp"


variable "acm_certificate_arn" {
  description = "ACM certificate ARN for Argo CD HTTPS ALB"
  type        = string
}

