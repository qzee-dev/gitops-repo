output "ecr_repositories" {
  description = "ECR repositories for the microservices"

  value = {
    for service, repository in aws_ecr_repository.microservice :
    service => repository.repository_url
  }
}
