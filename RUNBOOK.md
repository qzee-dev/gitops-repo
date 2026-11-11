# Infrastructure runbook

This runbook covers the three Kubernetes Terraform environments in this
repository: **dev, staging, and production**. Run one environment at a time,
from that environment's Terraform root.

The repository manages ECR infrastructure and bootstraps add-ons and ingress
on existing EKS clusters. It does not create the clusters, VPCs, worker nodes,
or application Deployments, and it is not the application source or GitOps
manifest source of truth.

## What each environment does

| Environment | Terraform root | State | Default ingress | Application delivery |
| --- | --- | --- | --- | --- |
| Dev | `k8s/dev/terraform/` | S3 key `dev/terraform.tfstate` | `f5-nginx` | The source repository's manual workflow updates an existing `Deployment` in namespace `dev` |
| Staging | `k8s/staging/terraform/` | S3 key `staging/terraform.tfstate` | `alb` | Staging Argo CD syncs the staging ApplicationSet |
| Production | `k8s/production/terraform/` | S3 key `production/terraform.tfstate` | `envoy` | Production Argo CD syncs the production ApplicationSet after approval |

Each root manages its own cluster add-ons and selected ingress through the
shared `k8s/modules/platform` code. A child module is not a separate state:
its resources belong to the environment root that called it. Never configure
two roots to manage the same cluster resource.

The release flow is:

1. [`qzee-dev/fintech-platform`](https://github.com/qzee-dev/fintech-platform)
   builds and publishes immutable images to ECR.
2. Its manual dev workflow deploys a verified image digest to an existing dev
   Deployment.
3. Its staging and production promotion workflows update values in
   [`qzee-dev/fintech-enterprise-gitops-manifest`](https://github.com/qzee-dev/fintech-enterprise-gitops-manifest).
4. Staging and production Argo CD instances sync only their respective
   ApplicationSets and clusters.

## Before you start

1. Install Terraform **1.10 or later** and confirm with `terraform version`.
   All three roots use S3's native state locking, supported from Terraform
   1.10.
2. Configure AWS credentials for the intended account and confirm the active
   identity with `aws sts get-caller-identity`.
3. Ensure that identity can read the target EKS cluster and manage the
   resources in the plan. The runner must be able to reach the EKS Kubernetes
   API for Helm and Kubernetes resources.
4. Collect the target cluster name, AWS region, VPC ID, and finance-approved
   cost center. Collect ingress domains, certificates, Route 53 details, and
   operational secrets only for the features you intend to enable.
5. Confirm the selected environment, state location, and current ownership of
   the cluster resources. Do not use another environment's variables, state,
   or credentials.

Keep credentials and secrets out of source control. The dev
`k8s/dev/terraform/terraform.tfvars` is tracked, so do not put secrets in it;
provide sensitive values through a protected runner environment or secret
store. Staging and production can use local `terraform.tfvars` files created
from their examples; those files are ignored by Git, but must still be kept
secure.

## Run an environment

Use the procedure for exactly one environment. The examples create and apply
a saved plan so the reviewed plan is the one applied. Treat the plan file as
sensitive, do not commit it, and remove it after a successful apply.

### Dev

Dev uses the S3 key `dev/terraform.tfstate`, separate from staging and
production. Configure its backend and credentials independently.

1. Change to the dev root and create the local backend configuration:

   ```sh
   cd k8s/dev/terraform
   cp backend.hcl.example backend.hcl
   ```

2. Edit `backend.hcl` and replace the bucket placeholder with the approved
   state bucket. Set `region` to that bucket's AWS region and keep the key as
   `dev/terraform.tfstate`; do not use either staging or production key.
3. Supply the actual dev `cluster_name`, `vpc_id`, and approved `cost_center`,
   plus any required settings for enabled features. The checked-in dev
   `terraform.tfvars` contains example selections, but its infrastructure
   values must be confirmed for your account.
4. Initialize with the dev backend, then format-check and validate. For a new
   root with no existing state, run:

   ```sh
   terraform init -backend-config=backend.hcl
   ```

   If this root has existing local state, follow
   [Moving existing state to S3](#moving-existing-state-to-s3) before
   initializing.

   Then run:

   ```sh
   terraform fmt -check
   terraform validate
   ```

5. Create and inspect a plan:

   ```sh
   terraform plan -out=dev.tfplan
   terraform show dev.tfplan
   ```

6. Confirm the AWS account, dev cluster, state key, tags, resource changes,
   and any replacements or deletions. Apply only if the plan is expected:

   ```sh
   terraform apply dev.tfplan
   ```

7. Remove the local plan file after the apply:

   ```sh
   rm dev.tfplan
   ```

Dev Terraform does not deploy the application. For an application release,
use the source repository's manual workflow; it requires the existing dev
`Deployment` in namespace `dev`.

### Staging

Staging uses the S3 key `staging/terraform.tfstate`. Configure its backend
separately from production.

1. Change to the staging root and create the local backend configuration:

   ```sh
   cd k8s/staging/terraform
   cp backend.hcl.example backend.hcl
   ```

2. Edit `backend.hcl` and replace the bucket placeholder with the approved
   state bucket. Set `region` to that bucket's AWS region. Keep the configured
   key as `staging/terraform.tfstate`; do not use the production key.
3. Create `terraform.tfvars` from the example and fill in the staging cluster,
   VPC, region, cost center, domains, certificates, and settings for the
   features to enable. Keep secrets secure:

   ```sh
   cp terraform.tfvars.example terraform.tfvars
   ```
4. Initialize this root with its backend, then format-check and validate:

   ```sh
   terraform init -backend-config=backend.hcl
   terraform fmt -check
   terraform validate
   ```

5. Create and inspect a plan:

   ```sh
   terraform plan -out=staging.tfplan
   terraform show staging.tfplan
   ```

6. Confirm the AWS account, staging cluster, state key, tags, and every
   replacement or deletion. Apply only the reviewed plan:

   ```sh
   terraform apply staging.tfplan
   ```

7. Remove the local plan file after the apply:

   ```sh
   rm staging.tfplan
   ```

Staging's default application ingress is ALB, and staging Argo CD also uses an
AWS Load Balancer Controller-managed ALB. Argo CD syncs the staging
ApplicationSet from the GitOps manifest repository.

### Production

Production uses the separate S3 key `production/terraform.tfstate`. Use
production-specific credentials, values, and approvals.

1. Change to the production root and create the local backend configuration:

   ```sh
   cd k8s/production/terraform
   cp backend.hcl.example backend.hcl
   ```

2. Edit `backend.hcl` and replace the bucket placeholder with the approved
   state bucket. Set `region` to that bucket's AWS region. Keep the configured
   key as `production/terraform.tfstate`; do not use the staging key.
3. Create `terraform.tfvars` from the example and fill in the production
   cluster, VPC, region, cost center, domains, certificates, and settings for
   the features to enable. Keep secrets in a protected secret source:

   ```sh
   cp terraform.tfvars.example terraform.tfvars
   ```
4. Initialize this root with its backend, then format-check and validate:

   ```sh
   terraform init -backend-config=backend.hcl
   terraform fmt -check
   terraform validate
   ```

5. Create and inspect a plan:

   ```sh
   terraform plan -out=production.tfplan
   terraform show production.tfplan
   ```

6. Confirm the AWS account, production cluster, state key, tags, and every
   replacement or deletion. Obtain the required production approval; apply
   only the reviewed plan:

   ```sh
   terraform apply production.tfplan
   ```

7. Remove the local plan file after the apply:

   ```sh
   rm production.tfplan
   ```

Production's default application ingress is Envoy, and production Argo CD uses
an AWS Load Balancer Controller-managed ALB. Argo CD syncs the production
ApplicationSet after the required promotion approval.

The checked-in production tfvars example points `acme_server` at Let's Encrypt
staging. Keep that endpoint for certificate testing; change it to the
approved production ACME directory before expecting publicly trusted
certificates.

## After applying

Confirm Terraform completed successfully and that the resulting resources
match the reviewed plan. Verify the configured add-ons and ingress are healthy
in the target cluster. For staging and production, also confirm the correct
Argo CD instance is reachable and syncing only its environment's
ApplicationSet. Application delivery is separate from Terraform: dev uses
the source repository's manual workflow, while staging and production use
their GitOps promotion workflows.

## Review the plan carefully

Do not apply if the plan targets the wrong AWS account, cluster, region, or
state key. Check environment tags and understand every resource replacement
and deletion. In particular:

- The AWS Load Balancer Controller and EKS Pod Identity Agent may be enabled
  automatically as dependencies of ingress, Argo CD, or Route 53 DNS-01.
- Disabling add-ons or changing `ingress_controller` can remove live
  resources. Review KEDA changes especially carefully because its CRDs can
  contain live `ScaledObject` resources.
- The cluster, VPC, worker nodes, and application Deployments are managed
  outside these platform roots.
- The current ingress options do **not** attach to a network-owned shared
  NLB. Envoy, NGINX, and F5 NGINX request their own NLB; ALB uses the AWS Load
  Balancer Controller. A shared-NLB design requires implementation and
  testing before changing these settings. See the [Kubernetes architecture
  guide](k8s/README.md).

## State and migration procedures

### Moving existing state to S3

The S3 backend examples use separate keys, encryption, and S3 lock files.
The approved bucket must already exist in the region configured in
`backend.hcl`. Enable bucket versioning and configure environment-scoped IAM
access to each environment's state object and lock file before initializing.
The dev, staging, and production backend examples use different keys
(`dev/terraform.tfstate`, `staging/terraform.tfstate`, and
`production/terraform.tfstate`) so their state stays isolated.

For dev's existing local state, back up `terraform.tfstate` securely before
changing backends. State can contain sensitive values; keep the backup
outside the repository in a protected location. Confirm the
`dev/terraform.tfstate` destination key is empty. From
`k8s/dev/terraform/`, run:

```sh
cp terraform.tfstate "$HOME/dev-terraform.tfstate.backup"
terraform init -migrate-state -backend-config=backend.hcl
```

Confirm the migration when prompted, then verify it with `terraform state
list`. Never migrate one environment's state into another environment's key.
For staging or production, if a local state is being migrated, follow the
same backup and empty-destination precautions using that environment's state
file and backend key. For a new root with no existing state, use
`terraform init -backend-config=backend.hcl` instead. Do not use
`-migrate-state` as a routine initialization option.

### One-time dev resource-address migration

The dev configuration moved several resources from root-level addresses into
`module.platform`. Only do this if `terraform state list` shows an old address
that still needs to be managed at the corresponding new address. Back up the
dev state securely first, skip absent old addresses and destinations already
in use, and run these commands from `k8s/dev/terraform/`:

```sh
terraform state mv 'aws_eks_addon.pod_identity_agent' 'module.platform.module.pod_identity_agent[0].aws_eks_addon.this'
terraform state mv 'aws_iam_policy.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_iam_policy.this'
terraform state mv 'aws_iam_role.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_iam_role.this'
terraform state mv 'aws_iam_role_policy_attachment.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_iam_role_policy_attachment.this'
terraform state mv 'aws_eks_pod_identity_association.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_eks_pod_identity_association.this'
terraform state mv 'helm_release.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].helm_release.this'
terraform state mv 'kubernetes_namespace.keda' 'module.platform.module.keda[0].kubernetes_namespace.this'
terraform state mv 'helm_release.keda' 'module.platform.module.keda[0].helm_release.this'
```

The destination module must be enabled in the dev configuration, and the
resource must remain owned by this root. Run `terraform plan` after the moves.
Do not apply if the plan unexpectedly replaces live add-ons or ingress
resources.

The optional `k8s/dev/terraform/ingress-dns01/` directory is a separate
standalone dev root with its own local state. Use it instead of the main dev
ingress path, not alongside it, if both would manage the same ingress,
cert-manager, or Pod Identity resources.

Terraform's `.terraform/` directory and `modules/modules.json` are generated
local initialization files. They are not Terraform state and should not be
edited or committed.

## ECR operations

ECR repositories and the image-publisher role are managed from `Ecr-Repo/`.
Supply an approved `cost_center`, initialize, validate, and review the plan
before applying. Images use immutable release tags; do not overwrite or retag
an existing image. The source workflow's publisher role is separate from
environment deployment roles.

Related operational docs:

- [ECR setup](Ecr-Repo/README.md)
- [Kubernetes architecture](k8s/README.md)
- [Dev environment](k8s/dev/README.md)
- [Staging environment](k8s/staging/README.md)
- [Production environment](k8s/production/README.md)
- [Source deployment runbook](https://github.com/qzee-dev/fintech-platform/blob/main/docs/DEPLOYMENT.md)
- [GitOps manifest runbook](https://github.com/qzee-dev/fintech-enterprise-gitops-manifest/blob/main/RUNBOOK.md)
