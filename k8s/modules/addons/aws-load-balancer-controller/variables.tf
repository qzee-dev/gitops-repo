variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "chart_version" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}