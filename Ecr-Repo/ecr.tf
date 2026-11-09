
################################################################################
# ECR Repositories
################################################################################

#####################################################################################
#
#####################################################################################

resource "aws_ecr_repository" "microservice" {
  for_each = local.ecr_repositories

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.repository_encryption_type
  }

   lifecycle {
    prevent_destroy = true
  }

  tags = {
    Service   = each.key
    Component = "container-image-repository"
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

