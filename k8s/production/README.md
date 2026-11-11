# Production EKS Platform

`terraform/` installs the production platform add-ons and a production-only
Argo CD instance on an **existing** EKS cluster. It does not create the cluster,
VPC, DNS zone, or ACM certificate. Terraform state is independent from dev and
staging; initialize and operate this root from this directory. It uses the S3
key `production/terraform.tfstate`, separate from the staging key. Never
initialize/apply this root with another environment's backend key.

Before the first init, copy `backend.hcl.example` to the ignored `backend.hcl`
and replace the bucket placeholder with the approved state bucket. The example
assumes the bucket is in `us-east-1`; change `region` if needed. The bucket
must already exist, have versioning enabled, block public access, and use
encryption. Terraform 1.10 or later is required for S3 state locking with
`use_lockfile`.

## Required inputs

Provide these as `TF_VAR_*` environment variables or an ignored local
`terraform.tfvars` file. To create the local file from the checked-in
production-specific template, run this from `k8s/production/terraform/`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Replace every placeholder with the approved production value before planning.
Do not use staging cluster, VPC, certificate, hostname, or cost-center values.
The local file is ignored by Git and should not be committed.

```text
aws_region
cluster_name
vpc_id
acm_certificate_arn
argocd_domain
aws_load_balancer_controller_chart_version
cost_center
```

Use the production cluster's region for the ACM certificate. The DNS hostname
must resolve privately to the internal ALB created for Argo CD. The cluster
must already be active, and the Terraform identity must be able to manage EKS
add-ons, IAM, Helm releases, and Kubernetes namespaces. Ensure private subnet
tags support discovery by the selected AWS Load Balancer Controller version.

## Plan and apply

Choose and review the AWS Load Balancer Controller chart version before
planning. If Pod Identity, KEDA, or the controller already exists, import it
into this root's state or reconcile ownership first; do not let Terraform
replace an add-on managed by another stack.

```bash
cp backend.hcl.example backend.hcl
```

Set the bucket name in `backend.hcl`. For a new state, initialize with:

```bash
terraform init -backend-config=backend.hcl
```

If migrating an existing local state, use this instead and confirm the
production key is empty before migrating:

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

Then, from this directory:

```bash
terraform fmt -check
terraform validate
terraform plan
```

Never point the production root at the staging key. Apply only after a
production review and approval. This root installs KEDA because the shared
service chart includes KEDA-scaled workloads. KEDA is protected from
accidental destruction because removing its CRDs can affect existing
`ScaledObject` resources.

After applying, create/verify the private DNS record for `argocd_domain`, then
bootstrap the production Argo CD project and
`applicationset-production.yaml` using the manifest repository's runbook. Set
the source repository's production `ARGOCD_SERVER` to the hostname only. The
current workflow uses a GitHub-hosted runner, which
cannot reach a private ALB; use a VPC-connected runner or another approved
private connectivity design before enabling promotion.

Dev uses the manual digest-based deployment workflow and does not install
Argo CD. This cluster should use only the production ApplicationSet.
The former combined `applicationset.yaml` manifest is not used. If it was
previously applied to the production cluster, verify this cluster's production
ApplicationSet is healthy before removing the old ApplicationSet. Review
generated Applications and finalizers to avoid deleting workloads. The
manifest repository should contain only
`applicationset-staging.yaml` and `applicationset-production.yaml`.

## Ingress and Shared Add-ons

The production root selects one dedicated controller module using
`ingress_controller`. Its default is `envoy`; supported values are `envoy`,
`nginx`, `alb`, and `f5-nginx`. The selected module creates routes for
`app.<suffix>`, `grafana.<suffix>`, and `prometheus.<suffix>`.

All controller modules use the `common` module for cert-manager, optional
Route 53 DNS-01 Pod Identity, kube-prometheus-stack, Grafana, Prometheus, and
the sample frontend. The Argo CD platform module owns the AWS Load Balancer
Controller once for Argo CD's ALB and AWS-backed LoadBalancer Services. The
ALB ingress module creates application routes and reuses that installation.
Set `ingress_domain_suffix` and provide
`TF_VAR_grafana_admin_password` (at least 16 characters) through a protected
secret source. For DNS-01, provide a public authoritative Route 53 hosted zone
ID and operations email; the Let's Encrypt staging endpoint is the default.
For ALB, provide an ACM certificate covering all three hostnames; the default
ALB scheme is internal.

Each root uses static Terraform module sources and `count` to instantiate
only the selected controller. When changing controller from a previously
applied configuration, review the plan carefully: module addresses changed
from the old `module.selected_ingress` address. Migrate existing Terraform
state deliberately if the plan proposes replacing resources that should
remain. Do not manage the same Helm release or Pod Identity association from
another Terraform state. See [`../README.md`](../README.md) for the module
layout and controller overview.

## Promotion contract

Application manifests are maintained in
`qzee-dev/fintech-enterprise-gitops-manifest`, not in this infrastructure
repository. The fintech production workflow updates:

```text
enterprise-gitops/environments/production/<service>/values.yaml
```

The workflow writes the resolved ECR repository, immutable image tag, and
verified digest before syncing Argo CD application `production-<service>`.
Protect the GitHub `production` Environment with required approval reviewers.

Production AWS resources must use `Environment=production` and the
finance-approved `CostCenter`, plus `Owner`, `ManagedBy`, and
`Project=fintech-platform`. ALB-backed services must include an
`alb.ingress.kubernetes.io/tags` annotation with `ManagedBy=AWSLoadBalancerController`.
Kubernetes objects should also carry matching owner/environment/cost-center
labels. Activate AWS cost-allocation tag keys in Billing/Cost Management.

Configure these GitHub Actions variables in the source repository's
`production` Environment:
`GITOPS_REPOSITORY=qzee-dev/fintech-enterprise-gitops-manifest`,
`GITOPS_REPOSITORY_NAME=fintech-enterprise-gitops-manifest`, and
`ARGOCD_SERVER` (hostname only, without `https://`). Configure secrets
`AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`, `ARGOCD_AUTH_TOKEN`, `GH_APP_ID`, and
`GH_APP_PRIVATE_KEY`. The GitOps repository must be accessible to the GitHub
App. The account ID must be the 12-digit AWS account that owns the ECR
repositories.

The workflow uses a GitHub-hosted runner. It cannot reach the environment's
private ALB; use a VPC-connected self-hosted runner or another approved private
connectivity design.
