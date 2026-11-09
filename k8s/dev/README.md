# Dev EKS Platform

## Scope

`terraform/` configures add-ons on an **existing** EKS cluster in `us-east-1`:
the EKS Pod Identity agent, AWS Load Balancer Controller, KEDA, and Argo CD. It
does not create the EKS cluster, VPC, worker nodes, or ACM certificate. KEDA
must be installed on every EKS cluster that runs KEDA-enabled consumer
workloads, before Argo CD syncs their `ScaledObject` resources. This Terraform
stack installs it on the existing dev cluster; repeat the add-on in the
Terraform stack that owns each additional cluster. The dev deployment workflow
currently updates Deployments directly with `kubectl` and the approved ECR
digest in the `dev` namespace.

The KEDA Terraform release is protected from accidental destruction because
uninstalling the chart can remove its CRDs and the `ScaledObject` resources
stored in them. Plan any KEDA removal or migration as a separate, deliberate
operation.

## Inputs Required Before Apply

The checked-in tfvars file supplies non-sensitive defaults. Provide the actual
cluster and finance values through local ignored tfvars or `TF_VAR_*` variables:

```text
cluster_name         existing dev EKS cluster name
vpc_id               VPC containing that cluster
acm_certificate_arn  ACM certificate in us-east-1 for the Argo CD hostname
argocd_domain        DNS hostname for the internal Argo CD ALB
cost_center          finance-approved cost center code
```

The EKS cluster must already be `ACTIVE`; the Terraform runner also needs
network access and Kubernetes permissions to install namespaces and Helm
releases. The cluster, VPC, and worker-node tags must be maintained by the
Terraform stack that owns those resources, not this add-on stack.

## FinOps Tags

Terraform-managed AWS resources receive `Owner`, `ManagedBy=Terraform`,
`Environment=dev`, `CostCenter`, and `Project=fintech-platform`. The Argo CD ALB
uses the `alb.ingress.kubernetes.io/tags` annotation with
`ManagedBy=AWSLoadBalancerController`, plus `Owner`, `Environment`,
`CostCenter`, `Project`, and `Service`. Future application manifests should
use Kubernetes labels such as `app.kubernetes.io/part-of`,
`app.kubernetes.io/managed-by`, `environment`, `owner`, and `cost-center`.
Activate AWS cost-allocation tag keys in Billing/Cost Management.

## Argo CD And Application Manifests

Argo CD is installed with an internal ALB. Its hostname and ACM certificate are
inputs; the checked-in sample values are templates, not deployable DNS/cert
identifiers. The Argo CD application manifests are intentionally not included
yet. When added, use app names `dev-<service>` if dev is moved under Argo CD;
the staging/production README files document their promotion contract.

The current dev workflow uses direct `kubectl set image`; if Argo CD begins
managing those same Deployments, change dev promotion to update GitOps and sync
Argo CD, otherwise Argo CD may revert the direct change. Confirm Argo CD CLI
gRPC compatibility through the ALB before enabling automated CLI syncs.
