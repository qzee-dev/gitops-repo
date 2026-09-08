locals {
  ecr_repositories = {
    for service in var.microservices :
    service => "${var.repository_prefix}/${service}"
  }
}
