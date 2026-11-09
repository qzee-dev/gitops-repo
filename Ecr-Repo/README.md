# Fintech Platform ECR Infrastructure

Terraform infrastructure for Fintech Platform ECR repositories and GitHub Actions authentication using AWS OIDC.

 ## Architecture

```
Fintech Monorepo Release Workflow
        │
        │ GitHub Actions + OIDC
        ▼
Shared Release IAM Role
        │
        │ ECR push permission
        ▼
Service-specific ECR Repository
        │
        ▼
Manifest Git Repo
        │
        ▼
Argo CD
        │
        ▼
EKS
```

 ## Services

 The platform contains these deployable services:

```
api-gateway
dlq-processor
mock-service
ledger-service
user-service
payment-service
wallet-service
transaction-service
notification-service
fraud-service
web
```

Terraform creates one immutable ECR repository per service in `us-east-1`.

```
repository_prefix = "fintech-platform"
```

The ECR repository is named `fintech-platform/<service>`.

 For example:

```
api-gateway
 │
 ├── GitHub repository: qzee-dev/fintech-platform
 ├── IAM role:          GitHubActionsECRRelease
 └── ECR repository:    fintech-platform/api-gateway
```

 The same pattern is used for every service.

 ## `for_each` Resource Mapping

 Terraform uses the service key to create matching resources:

```
resource "aws_ecr_repository" "service" {
        for_each = local.ecr_repositories

        name = each.value
}
```

 The release workflow assumes one shared IAM role:

```
GitHubActionsECRRelease
```

 The role can publish to repositories under `fintech-platform/*`. The selected
 service determines the repository used by the workflow.

```
fintech-platform/<service>
```

 This creates the following relationship:

```
service key
    │
        ├── api-gateway
        │    └── fintech-platform/api-gateway
    │
        ├── ledger-service
        │    └── fintech-platform/ledger-service
    │
    └── ...
```

 ## Repository Naming

 Naming must remain consistent:

```
GitHub Repository
        qzee-dev/fintech-platform

IAM Role
        GitHubActionsECRRelease

ECR Repository
        fintech-platform/<service>
```

 Example:

```
qzee-dev/fintech-platform (develop branch)
        │
        ▼
GitHubActionsECRRelease
        │
        ▼
fintech-platform/<selected-service>
```

 This naming convention provides a clear, non-conflicting relationship between the application and its AWS resources.

## ECR Access Scope

The monorepo release role can push and inspect images only in repositories under
the `fintech-platform/` prefix. It is not a separate IAM boundary per service.

The workflow is trusted only for the configured repository and branch:

```
repo:qzee-dev/fintech-platform:ref:refs/heads/develop
```

The GitHub Actions secret `AWS_ROLE_ARN` should be set to the
`github_actions_ecr_role_arn` Terraform output. No long-lived AWS access keys
are needed.

 ## Image Naming

Images use the service-specific ECR repository and immutable service-version-commit tag:

```
<account>.dkr.ecr.us-east-1.amazonaws.com/fintech-platform/<service>:<service>-<version>-<short-commit>
```

 Example:

```
123456789012.dkr.ecr.us-east-1.amazonaws.com/fintech-platform/ledger-service:ledger-service-v1.3.5-a1b2c3d
```

 Do not use `latest` for production deployments.

## FinOps Tags

Every AWS resource managed by this stack inherits these tags:

```text
Owner       = qzee-dev (override with the accountable team/owner)
ManagedBy   = Terraform
Environment = shared
CostCenter  = required finance-approved cost center
Project     = fintech-platform
```

Each ECR repository also has `Service` and `Component` tags. ECR is tagged
`shared` because the same published image can be promoted to dev, staging, and
production. Set `cost_center` through `TF_VAR_cost_center` or a local ignored
tfvars file before planning/applying. Activate the approved cost-allocation tag
keys in AWS Billing/Cost Management before expecting them in Cost Explorer.

 ## GitHub OIDC

 Only **one GitHub OIDC provider** is required.

```
GitHub
   │
   │ OIDC
   ▼
AWS IAM OIDC Provider
   │
        └── GitHubActionsECRRelease
```

The OIDC trust is restricted to `qzee-dev/fintech-platform` on `develop`. If
the OIDC provider already exists in the AWS account, import it into this
Terraform state before applying to avoid a duplicate-provider error.

 No long-lived AWS access keys are required.

 ## Terraform Files

```
fintech-platform-ecr-infrastructure/
├── README.md
├── version.tf
├── provider.tf
├── variable.tf
├── local.tf
├── ecr.tf
├── github-actions-ecr.tf
├── output.tf
└── terraform.tfvars
```

 The important design rule is:

```
ONE monorepo release workflow
        ├── ONE OIDC-trusted release role
        └── ONE ECR repository per service
```

The role is limited to the fintech ECR repository namespace. Environment-specific
deployment roles should remain separate from this image-publishing role.
