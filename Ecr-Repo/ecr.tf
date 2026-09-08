
################################################################################
# ECR Repositories
################################################################################
/*
locals {
  microservices = [
    "auth",
    "users",
    "orders",
    "payments",
    "notifications",
    "catalog",
    "gateway",
    "reporting"
  ]
}
*/
#####################################################################################
#
#####################################################################################

resource "aws_ecr_repository" "microservice" {
  for_each = toset(local.microservices)

  name                 = "myapp/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

   lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project     = "myapp"
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = each.value
  }
}

###############################################################################
#
################################################################################
resource "aws_ecr_lifecycle_policy" "microservice" {
  for_each = aws_ecr_repository.microservice

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the latest 30 tagged images"

        selection = {
          tagStatus   = "tagged"
          tagPrefixList = [""]

          countType   = "imageCountMoreThan"
          countNumber = 30
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}

