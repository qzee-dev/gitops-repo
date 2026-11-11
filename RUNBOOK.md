# Infrastructure repository runbook

## What this repository owns

`qzee-dev/gitops-repo` provides shared AWS and Kubernetes infrastructure. It is
not the application source repository and is not the application GitOps source
of truth.

| Path | Responsibility |
| --- | --- |
| `Ecr-Repo/` | Creates immutable ECR repositories under `fintech-platform/` and the GitHub OIDC role used by the source repo's release workflow. |
| `k8s/dev/terraform/` | Installs Pod Identity, AWS Load Balancer Controller, and KEDA on an existing dev EKS cluster. It does not install Argo CD or create the cluster. |
| `k8s/modules/argocd-platform/` | Shared Terraform module for Pod Identity, AWS Load Balancer Controller, KEDA, and one environment's Argo CD instance. |
| `k8s/staging/terraform/`, `k8s/production/terraform/` | Independent Terraform roots/states for the existing staging and production EKS clusters. They do not create clusters or networks. |

### How it fits the deployment flow

1. The source repository, `qzee-dev/fintech-platform`, builds an image and
   publishes it to one of this repository's `fintech-platform/<service>` ECR
   repositories.
2. Its manually dispatched dev workflow lists successful release runs, then
   uses the selected release run ID and an environment-specific AWS role to
   update the existing Deployment in namespace `dev` with the verified image
   digest. The Deployment must already exist; the workflow does not install
   application manifests or create it.
3. Its staging and production promotion workflows update values in
   `qzee-dev/fintech-enterprise-gitops-manifest`.
4. The environment-specific Argo CD reads its matching manifest ApplicationSet
   and syncs applications to the local staging or production cluster.

The target architecture has no Argo CD application deployment in dev: dev uses
the direct manual workflow, while staging and production each use their own
Argo CD instance and ApplicationSet.

The ECR publisher role is separate from the dev/staging/production deployment
roles. Do not reuse the image-publisher role as a cluster deployment role.

## Tagging policy

The ECR repository is `fintech-platform/<service>`. The source repository
creates immutable image tags of the form
`<service>-<semantic-version>-<7-char-source-commit>`, such as
`payment-service-v1.2.3-a1b2c3d`. ECR's lifecycle policy retains the latest 30
tagged images per service repository. Never overwrite an immutable tag or use
`latest`; publish a new version for a new build.

The image tag is a readable release label; the image digest is the exact
deployable identity. Dev deploys by digest, and staging/production preserve the
same tag/digest pair in their manifest values. Do not rebuild an image during
promotion. Git commit SHAs identify changes to this infrastructure repo and
are separate from release tags.

Terraform-managed AWS resources inherit `Owner`, `ManagedBy`, `Environment`,
`CostCenter`, and `Project`. ECR repositories add `Service` and
`Component=container-image-repository`; the shared registry uses
`Environment=shared`. The dev platform stack uses `Environment=dev`. Supply the
finance-approved `CostCenter`; do not commit a placeholder or secret.

## Operating ECR and the release publisher role

Run these commands from `Ecr-Repo/` with Terraform >= 1.6 and AWS credentials
for the target account:

1. Verify `terraform.tfvars` identifies `us-east-1`,
   `qzee-dev/fintech-platform`, and branch `develop`.
2. Supply `cost_center` locally (for example:
   `export TF_VAR_cost_center='<approved-value>'`) and do not commit secrets or
   local state. Terraform state is currently local; use one trusted
   operator/workspace at a time until a reviewed remote backend is configured.
3. Initialize and inspect the plan:

   ```bash
   terraform init
   terraform fmt -check
   terraform validate
   terraform plan
   ```

4. Review the plan for the 11 service repositories, immutable tags, ECR
   lifecycle policies, and GitHub OIDC role. If the account already has the
   GitHub OIDC provider, import/manage it before applying rather than creating
   a duplicate provider.
5. Apply only an approved plan:

   ```bash
   terraform apply
   ```

6. Record the `github_actions_ecr_role_arn` output and configure it as
   `AWS_ROLE_ARN` in the source repository's release configuration. Set
   `AWS_ACCOUNT_ID` to the 12-digit account ID. The trust must match the source
   repo and `develop` branch.
7. Verify repository URLs and role identity with `terraform output` and a test
   release. The source workflow must successfully push a uniquely tagged image
   to `fintech-platform/<service>`.

The account ID is deliberately not checked into this repository's application
manifests. It is an environment-specific configuration value.

## Operating the dev EKS platform add-ons

This stack expects an already-created, active dev EKS cluster. It installs
add-ons; it does not provision the VPC, cluster, node groups, ACM certificate,
or application Deployments.

1. In `k8s/dev/terraform/`, provide real values for `cluster_name`, `vpc_id`,
   finance-approved `cost_center` using ignored local tfvars or `TF_VAR_*`
   environment variables. Do not commit account secrets or private endpoint
   credentials.
2. Confirm AWS credentials can describe the cluster and the operator can reach
   the Kubernetes API with sufficient permissions for Helm releases, CRDs,
   namespaces, and add-ons.
3. Review and apply the stack:

   ```bash
   terraform init
   terraform fmt -check
   terraform validate
   terraform plan
   terraform apply
   ```

   Inspect the plan carefully. The dev root does not install Argo CD. If
   migrating from a prior state that still tracks Argo CD, first inspect the
   plan for Argo CD Helm release/namespace destruction and follow the safe
   retirement steps below. The KEDA resource is protected because uninstalling
   it can remove CRDs and stored `ScaledObject` objects.

4. Verify the cluster is active and KEDA CRDs are installed:

   ```bash
   aws eks describe-cluster --name "$CLUSTER_NAME" --region us-east-1
   kubectl get crd scaledobjects.keda.sh
   ```

5. Set the source repository's `dev` Environment variables/secrets:
   `EKS_CLUSTER_NAME`, `AWS_ACCOUNT_ID`, and `AWS_ROLE_ARN`. Grant that role
   only the required ECR read, `eks:DescribeCluster`, and namespace-`dev`
   Kubernetes permissions. Ensure worker nodes can pull from the ECR account.
6. The manual dev workflow in `qzee-dev/fintech-platform` uses
   `workflow_dispatch`: run `list`, choose successful release run ID(s), then
   run `deploy`. It validates release metadata and the digest, verifies the
   existing `deployment/<service>` in namespace `dev`, sets the container
   image to the ECR `repository@digest`, waits for rollout, and verifies the
   image and ready replicas. This Terraform stack does not create those
   application Deployments; bootstrap them before the first dev release.

## Provisioning staging and production Argo CD

The staging and production Terraform roots use separate state and a shared
add-on module, but own distinct S3 backend keys:
`staging/terraform.tfstate` and `production/terraform.tfstate`. Each root has
its own backend configuration example and working directory. Always initialize,
plan, and apply from the matching environment directory; never copy, rename, or
reuse another environment's state. The bucket must be versioned, encrypted,
private, and shared only by approved Terraform operators. Never reuse the dev
state file, which remains local to the dev root. Each staging/production root
expects an existing environment EKS cluster, VPC, ACM certificate, private DNS
name, finance-approved cost center, and an explicit AWS Load Balancer
Controller chart version. Supply these values with `TF_VAR_*` variables or
ignored local tfvars. Scope backend IAM access by environment: the staging
role should access only the staging state object and lock object, and the
production role only the production objects. Separate state keys do not
restrict users whose AWS role can access both.

Before planning, check whether Pod Identity, KEDA, or the AWS Load Balancer
Controller is already installed. Import existing resources into the matching
root or agree on one owner; do not let Terraform replace resources owned by
another stack. Ensure private subnets have the discovery tags required by the
selected AWS Load Balancer Controller version. Review and apply staging first,
then production under the required production approval. Confirm private DNS
and runner connectivity; GitHub-hosted runners cannot reach the configured
internal ALBs.

On each environment cluster, bootstrap `project.yaml` and only that
environment's ApplicationSet from the manifest repository. Set the matching
GitHub Environment's `ARGOCD_SERVER` to the new hostname and verify a
promotion end-to-end.

### Retiring Argo CD from dev

The dev Terraform root no longer declares an Argo CD Helm release or namespace.
If the previous dev root has Argo CD resources in its Terraform state,
removing the declarations will produce a destroy plan for those resources.
Inspect the existing dev state and cluster before applying. Check whether the
existing dev Argo CD instance, if any, has Applications that still own
workloads that must remain, and handle their finalizers and deletion behavior
deliberately. Then review the Terraform plan and confirm it removes only the
intended Argo CD release/namespace, not KEDA, its CRDs, the AWS Load Balancer
Controller, Pod Identity, or dev application Deployments. Do not apply dev
state changes to staging or production; those roots retain their separate
Argo CD installations through the shared module.

## Change and recovery rules

- Review Terraform plans before every apply. Never remove the shared OIDC
  provider, ECR repositories, staging/production Argo CD instances, or KEDA as
  incidental cleanup.
- ECR tags are immutable. Publish a new release tag; do not overwrite or
  retag an existing image.
- For a Kubernetes add-on incident, inspect Terraform state/plan and the
  add-on's namespace/events before applying corrective changes.
- For application incidents, use the source repo's release/promotion workflow
  and the manifest repo's environment history; this repository does not own
  application image versions.

## Related runbooks

- Source build and environment deployment:
  [fintech-platform deployment runbook](https://github.com/qzee-dev/fintech-platform/blob/main/docs/DEPLOYMENT.md)
- Helm, values, and Argo CD behavior:
  [enterprise manifest runbook](https://github.com/qzee-dev/fintech-enterprise-gitops-manifest/blob/main/RUNBOOK.md)
- ECR-specific architecture details: [Ecr-Repo README](Ecr-Repo/README.md)
