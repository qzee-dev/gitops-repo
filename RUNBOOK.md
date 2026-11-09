# Infrastructure repository runbook

## What this repository owns

`qzee-dev/gitops-repo` provides shared AWS and Kubernetes infrastructure. It is
not the application source repository and is not the application GitOps source
of truth.

| Path | Responsibility |
| --- | --- |
| `Ecr-Repo/` | Creates immutable ECR repositories under `fintech-platform/` and the GitHub OIDC role used by the source repo's release workflow. |
| `k8s/dev/terraform/` | Installs platform add-ons on an existing dev EKS cluster, including Argo CD, KEDA, Pod Identity, and AWS Load Balancer Controller. It does not create the cluster. |
| `k8s/staging/`, `k8s/production/` | Documentation/reserved infrastructure locations. Application values are in `qzee-dev/fintech-enterprise-gitops-manifest`. |

### How it fits the deployment flow

1. The source repository, `qzee-dev/fintech-platform`, builds an image and
   publishes it to one of this repository's `fintech-platform/<service>` ECR
   repositories.
2. Its manual dev workflow uses an environment-specific AWS role to update the
   existing Deployment in namespace `dev` with the exact image digest.
3. Its staging and production promotion workflows update values in
   `qzee-dev/fintech-enterprise-gitops-manifest`.
4. Argo CD reads that manifest repository and syncs staging and production
   applications to the cluster configured as its destination.

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
   `acm_certificate_arn`, `argocd_domain`, and finance-approved `cost_center`
   using ignored local tfvars or `TF_VAR_*` environment variables. Do not commit
   account secrets or private endpoint credentials.
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

   Inspect the plan carefully, especially changes that replace Argo CD, KEDA,
   or their CRDs. The KEDA resource is protected because uninstalling it can
   remove CRDs and stored `ScaledObject` objects.

4. Verify the cluster is active, Argo CD is healthy, and KEDA CRDs are
   installed:

   ```bash
   aws eks describe-cluster --name "$CLUSTER_NAME" --region us-east-1
   kubectl get pods -n argocd
   kubectl get crd scaledobjects.keda.sh
   ```

5. Set the source repository's `dev` Environment variables/secrets:
   `EKS_CLUSTER_NAME`, `AWS_ACCOUNT_ID`, and `AWS_ROLE_ARN`. Grant that role
   only the required ECR read, `eks:DescribeCluster`, and namespace-`dev`
   Kubernetes permissions. Ensure worker nodes can pull from the ECR account.
6. The dev workflow updates an existing `deployment/<service>` in namespace
   `dev`; this Terraform stack does not create those application Deployments.
   Verify the deployment exists before the first dev release.

Argo CD is installed by this stack, but the ApplicationSet's current destination
is the local cluster where that Argo CD runs. The ApplicationSet manages
staging and production applications, not dev. If staging and production belong
on separate clusters, register those clusters with Argo CD and change the
ApplicationSet destinations before deploying there. Do not assume separate
clusters are configured merely because folders exist for each environment.

## Change and recovery rules

- Review Terraform plans before every apply. Never remove the shared OIDC
  provider, ECR repositories, Argo CD, or KEDA as incidental cleanup.
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
