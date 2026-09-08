################################################################################
# GitHub Application Repository → Service Mapping
################################################################################

locals {
  github_service_repositories = {
    auth          = "myorg/myapp-auth"
    users         = "myorg/myapp-users"
    orders        = "myorg/myapp-orders"
    payments      = "myorg/myapp-payments"
    notifications = "myorg/myapp-notifications"
    catalog       = "myorg/myapp-catalog"
    gateway       = "myorg/myapp-gateway"
    reporting     = "myorg/myapp-reporting"
  }
}

################################################################################
# GitHub Actions ECR Push Roles
#
# One IAM role per microservice.
#
# Example:
#
# myorg/myapp-auth
#       ↓
# GitHubActionsECR-auth
#       ↓
# myapp/auth
################################################################################

resource "aws_iam_role" "github_actions_ecr" {
  for_each = local.github_service_repositories

  name = "GitHubActionsECR-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${each.value}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "GitHub Actions ECR push"
    Service = each.key
  }
}

################################################################################
# GitHub Actions ECR Push IAM Policies
#
# Each policy can push ONLY to the ECR repository belonging to that service.
#
# auth       → myapp/auth
# users      → myapp/users
# orders     → myapp/orders
# etc.
################################################################################

resource "aws_iam_policy" "github_actions_ecr_push" {
  for_each = local.github_service_repositories

  name        = "GitHubActionsECRPush-${each.key}"
  description = "Allows ${each.key} GitHub Actions workflow to push to its ECR repository"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ECRAuthentication"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },

      {
        Sid    = "PushApplicationImages"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = [
          aws_ecr_repository.microservice[each.key].arn
        ]
      }
    ]
  })

  tags = {
    Purpose = "CI/CD ECR image push"
    Service = each.key
  }
}

################################################################################
# Attach Each ECR Push Policy to Its Matching IAM Role
################################################################################

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  for_each = local.github_service_repositories

  role       = aws_iam_role.github_actions_ecr[each.key].name
  policy_arn = aws_iam_policy.github_actions_ecr_push[each.key].arn
}
