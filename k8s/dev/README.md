# Dev EKS platform

The dev Terraform root configures add-ons and ingress on the existing dev EKS
cluster. It does not create the cluster, VPC, worker nodes, or application
Deployments.

## Current integration

```mermaid
flowchart LR
    Root["Dev Terraform root"] --> Platform["modules/platform"]
    Root --> State["Dev S3 state"]
    Platform --> Addons["Configured add-ons"]
    Platform --> Ingress["Selected ingress<br/>default: f5-nginx"]
    Addons --> Cluster["Existing dev EKS"]
    Ingress --> Cluster
    Release["Manual source-repo deploy workflow"] -->|"verified ECR digest"| Deployment["Existing dev Deployment"]
    Deployment --> Cluster
```

Terraform owns the platform add-ons and ingress. The manually dispatched
release workflow in [`qzee-dev/fintech-platform`](https://github.com/qzee-dev/fintech-platform)
updates an existing `Deployment` in namespace `dev` to a verified ECR image
digest. It does not create that Deployment. Dev does not use Argo CD for
application releases.

## Inputs and operations

Set the actual `cluster_name`, `vpc_id`, and finance-approved `cost_center`
in the dev tfvars or through `TF_VAR_*`. The checked-in dev tfvars is tracked:
do not add secrets to it. Provide any required ingress hostname, certificate,
DNS, or secret values for the options you enable. The cluster must be active
and reachable from the Terraform runner.

Configure `backend.hcl` from `backend.hcl.example` with the approved state
bucket and preserve the `dev/terraform.tfstate` key. For an existing local
state, securely back it up and migrate it to this S3 key; see the
[runbook](../../RUNBOOK.md#moving-existing-state-to-s3).

From `k8s/dev/terraform/`:

```sh
cp backend.hcl.example backend.hcl
# Set the approved bucket in backend.hcl before initialization.
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review the plan before applying, especially when disabling an add-on or
changing `ingress_controller`. The KEDA release has `prevent_destroy` because
its CRDs may contain application resources.

## Existing shared NLB

**Current status:** the default F5 NGINX module requests its own NLB. It does
not use the network-owned shared NLB, and setting
`enable_aws_load_balancer_controller = false` will not change that.

**Intended shared-NLB role:** the network owner supplies a dev-specific
listener/target group on the shared NLB. The dev root would continue to own
the dev F5 NGINX gateway and routes in the dev cluster, changed to receive
traffic from that target group without creating an AWS load balancer. Dev
application releases continue through the existing manual digest deployment
workflow. Argo CD is off by default, so there is no Argo CD endpoint to
redesign unless it is explicitly enabled.

This requires implementing the shared target integration and changing the
platform's derived controller dependency before turning the controller off.
See the [shared-NLB design and requirements](../README.md#using-a-network-owned-shared-nlb).

## Existing state migration

If the existing dev state has the previous root-level resource addresses,
perform the one-time `terraform state mv` operations documented in the
[runbook](../../RUNBOOK.md) before planning. Do not run moves for resources
that are absent or already at the destination. Back up the state first.

The optional `terraform/ingress-dns01/` directory is a separate standalone
Terraform root and state, not part of this platform composition. Use it only
instead of the main dev ingress path; do not let both roots manage the same
ingress, cert-manager, or Pod Identity resources.
