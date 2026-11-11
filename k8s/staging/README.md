# Staging EKS Platform

`terraform/` installs the staging platform add-ons and a staging-only Argo CD
instance on an **existing** EKS cluster. It does not create the cluster, VPC,
DNS zone, or ACM certificate. Terraform state is independent from dev and
production; initialize and operate this root from this directory. It uses the
S3 key `staging/terraform.tfstate`, separate from the production key. Never
initialize/apply this root with another environment's backend key.

Before the first init, copy `backend.hcl.example` to the ignored `backend.hcl`
and replace the bucket placeholder with the approved state bucket. The example
assumes the bucket is in `us-east-1`; change `region` if needed. The bucket
must already exist, have versioning enabled, block public access, and use
encryption. Terraform 1.10 or later is required for S3 state locking with
`use_lockfile`.

## Required inputs

Provide these as `TF_VAR_*` environment variables or in the ignored local
`terraform/terraform.tfvars` file. A placeholder file is included; replace its
values with the staging environment's inputs. To recreate it, copy
`terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

```text
aws_region
cluster_name
vpc_id
acm_certificate_arn
argocd_acm_certificate_arn
argocd_domain
ingress_alb_certificate_arn (when ingress_controller = "alb")
aws_load_balancer_controller_chart_version
cost_center
```

Use the staging cluster's region for the ACM certificate. The DNS hostname
must resolve privately to the internal ALB created for Argo CD. The cluster
must already be active, and the Terraform identity must be able to manage EKS
add-ons, IAM, Helm releases, and Kubernetes namespaces. Ensure private subnet
tags support discovery by the selected AWS Load Balancer Controller version.

## Plan and apply

Choose and review the AWS Load Balancer Controller chart version before
planning. If an add-on already exists, import it into this root's state or
reconcile ownership first; do not let Terraform replace an add-on managed by
another stack.

```bash
cp backend.hcl.example backend.hcl
```

Set the bucket name in `backend.hcl`. For a new state, initialize with:

```bash
terraform init -backend-config=backend.hcl
```

If migrating an existing local state, use this instead and confirm the staging
key is empty before migrating:

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

Then, from this directory:

```bash
terraform fmt -check
terraform validate
terraform plan
```

Never point the staging root at the production key. Apply only after reviewing
the plan and confirming the target cluster and environment tags. This root
installs KEDA because the shared service chart includes KEDA-scaled workloads.
KEDA is protected from accidental destruction because removing its CRDs can
affect existing `ScaledObject` resources.

After applying, create/verify the private DNS record for `argocd_domain`, then
bootstrap the staging Argo CD project and
`applicationset-staging.yaml` using the manifest repository's runbook. Set the
source repository's staging `ARGOCD_SERVER` to the hostname only. The current
workflow uses a GitHub-hosted runner, which
cannot reach a private ALB; use a VPC-connected runner or another approved
private connectivity design before enabling promotion.

Dev uses the manual digest-based deployment workflow and does not install
Argo CD. This cluster should use only the staging ApplicationSet.
The former combined `applicationset.yaml` manifest is not used. If it was
previously applied to the staging cluster, verify this cluster's staging
ApplicationSet is healthy before removing the old ApplicationSet. Review
generated Applications and finalizers to avoid deleting workloads. The
manifest repository should contain only
`applicationset-staging.yaml` and `applicationset-production.yaml`.

## Ingress and Shared Add-ons

The staging root uses the same selectable `modules/platform` composition as
dev and production. Set add-on flags independently in the local tfvars file;
`ingress_controller` selects exactly one of `none`, `envoy`, `nginx`,
`f5-nginx`, or `alb`. NLB-backed controllers use the configurable
`ingress_load_balancer_scheme`; ALB mode requires its own ACM certificate ARN.
Ingress selection automatically includes the AWS Load Balancer Controller
and Pod Identity Agent where required. The Argo CD ALB reuses that controller.

The staging root selects one dedicated controller module using
`ingress_controller`. Its default and checked-in example are `alb`. Supported
values are `envoy`, `nginx`, `alb`, and `f5-nginx`.
The selected module creates routes for `app.<suffix>`, `grafana.<suffix>`, and
`prometheus.<suffix>`.

All controller modules use the `common` module for cert-manager, optional
Route 53 DNS-01 Pod Identity, kube-prometheus-stack, Grafana, Prometheus, and
the sample frontend. The Argo CD platform module owns the AWS Load Balancer
Controller once for Argo CD's ALB and AWS-backed LoadBalancer Services. The
ALB ingress module creates application routes and reuses that installation.
Provide `ingress_domain_suffix` and
`TF_VAR_grafana_admin_password` (at least 16 characters). For DNS-01, provide
a public authoritative Route 53 hosted zone ID and operations email; the
Let's Encrypt staging endpoint is the default. For ALB, provide an ACM
certificate covering all three hostnames; the default ALB scheme is internal.

Each root uses static Terraform module sources and `count` to instantiate
only the selected controller. When changing controller from a previously
applied configuration, review the plan carefully: module addresses changed
from the old `module.selected_ingress` address. Migrate existing Terraform
state deliberately if the plan proposes replacing resources that should
remain. Do not manage the same Helm release or Pod Identity association from
another Terraform state. See [`../README.md`](../README.md) for the module
layout and controller overview.
