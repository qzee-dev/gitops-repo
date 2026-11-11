variable "environment" {
  type = string
}

variable "app_namespace" {
  type = string
}

variable "image" {
  type    = string
  default = "nginx:1.29.2-alpine"
}

variable "replicas" {
  type    = number
  default = 2
}