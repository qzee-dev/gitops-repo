variable "aws_region" {
  description = "AWS region where the ECR repositories will be created"
  type        = string
}

variable "project_name" {
  description = "Project name used for tagging"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "repository_prefix" {
  description = "Prefix used for ECR repository names"
  type        = string
  default     = "myapp"
}

variable "microservices" {
  description = "Microservices for which ECR repositories will be created"
  type        = set(string)

  default = [
     "api-gateway"
     "user-service"
     "payment-service"
     "wallet-service"
     "transaction-service"
     "notification-service"
     "fraud-service"

  ]
}

variable "image_tag_mutability" {
  description = "Whether ECR image tags can be overwritten"
  type        = string

  default = "IMMUTABLE"

  validation {
    condition = contains(
      ["MUTABLE", "IMMUTABLE"],
      var.image_tag_mutability
    )

    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable ECR image scanning when images are pushed"
  type        = bool
  default     = true
}

variable "repository_encryption_type" {
  description = "ECR repository encryption type"
  type        = string
  default     = "AES256"

  validation {
    condition = contains(
      ["AES256", "KMS"],
      var.repository_encryption_type
    )

    error_message = "repository_encryption_type must be AES256 or KMS."
  }
}


variable "github_application_repository" {
  description = "GitHub application repository allowed to push images to ECR. Format: organization/repository"
  type        = string
}





