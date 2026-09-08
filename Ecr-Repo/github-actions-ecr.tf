################################################################################
# GitHub Actions ECR Push Role and Trust policy
################################################################################

resource "aws_iam_role" "github_actions_ecr" {
  name = "GitHubActionsECRPush"

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
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_application_repository}:*"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "GitHub Actions ECR push"
  }
}

################################################################################
# GitHub Actions ECR Push IAM Policy
################################################################################

resource "aws_iam_policy" "github_actions_ecr_push" {
  name        = "GitHubActionsECRPush"
  description = "Allows CI/CD to authenticate with ECR and push MyApp images"

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
          for repository in aws_ecr_repository.microservice :
          repository.arn
        ]
      }
    ]
  })

  tags = {
    Purpose = "CI/CD ECR image push"
  }
}



################################################################################
# Attach ECR Push Policy to GitHub Actions Role
################################################################################

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = aws_iam_policy.github_actions_ecr_push.arn
}









