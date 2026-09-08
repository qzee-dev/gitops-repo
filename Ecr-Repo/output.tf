output "ecr_repositories" {
  description = "ECR repositories for the microservices"

  value = {
    for service, repository in aws_ecr_repository.microservice :
    service => repository.repository_url
  }
}



output "ecr_repository_arns" {
  description = "ECR repository ARNs indexed by microservice"

  value = {
    for service, repository in aws_ecr_repository.microservice :
    service => repository.arn
  }
}

output "ecr_registry_url" {
  description = "AWS ECR registry URL"

  value = split("/", values(aws_ecr_repository.microservice)[0].repository_url)[0]
}
