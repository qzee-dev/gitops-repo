variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "chart_version" {
  type = string
}

variable "enable_route53_dns01" {
  type = bool
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}