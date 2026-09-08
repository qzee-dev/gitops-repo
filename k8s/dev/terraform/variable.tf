variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type    = string
  default = "my-eks-cluster"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "app_namespace" {
  type    = string
  default = "myapp"
