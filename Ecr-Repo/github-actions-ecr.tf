################################################################################
# Shared GitHub Actions Release Role
################################################################################

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role" "github_actions_ecr_release" {
  name = "GitHubActionsECRRelease"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubFintechReleaseWorkflow"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_application_repository}:ref:refs/heads/${var.github_application_branch}"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "GitHub Actions fintech release image publishing"
    Project = var.project_name
  }
}

resource "aws_iam_policy" "github_actions_ecr_release" {
  name        = "GitHubActionsECRRelease"
  description = "Allows the fintech monorepo release workflow to publish images to its ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthentication"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "DescribeECRRepositories"
        Effect   = "Allow"
        Action   = ["ecr:DescribeRepositories"]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.repository_prefix}/*"
        ]
      },
      {
        Sid    = "PublishAndVerifyFintechImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.repository_prefix}/*"
        ]
      }
    ]
  })

  tags = {
    Purpose = "CI/CD ECR release publishing"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_release" {
  role       = aws_iam_role.github_actions_ecr_release.name
  policy_arn = aws_iam_policy.github_actions_ecr_release.arn
}
