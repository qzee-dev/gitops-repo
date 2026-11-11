# Dev EKS Platform

## Scope

`terraform/` configures add-ons on an **existing** EKS cluster in `us-east-1`:
the EKS Pod Identity agent, AWS Load Balancer Controller, KEDA, and the selected
ingress platform. It does not create the EKS cluster, VPC, worker nodes, or
application Deployments.

The intended steady state is:

- **Dev:** deploy application releases through the source repository's
  manually dispatched `deploy-dev.yaml` workflow. It updates an existing
  Deployment in namespace `dev` directly to a verified ECR image digest.
  Argo CD is not the dev application deployment mechanism.
- **Staging and production:** each environment has its own Argo CD instance,
  ApplicationSet, and promotion workflow. Those instances sync only to their
  respective clusters.

The default dev profile does not enable Argo CD. It can be enabled explicitly
with `enable_argocd`, but the documented dev application release flow remains
the manual digest-based workflow. Ingress controllers and add-ons are selected
independently from application releases.

KEDA must be installed on every EKS cluster that runs KEDA-enabled consumer
workloads, before those workloads' `ScaledObject` resources are applied. This
Terraform stack installs it on the existing dev cluster; repeat the add-on in
the Terraform stack that owns each additional cluster.

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
cost_center          finance-approved cost center code
```

The EKS cluster must already be `ACTIVE`; the Terraform runner also needs
network access and Kubernetes permissions to install namespaces and Helm
releases. The cluster, VPC, and worker-node tags must be maintained by the
Terraform stack that owns those resources, not this add-on stack.

The dev Terraform configuration no longer declares Argo CD. If prior dev
Terraform state still tracks `helm_release.argocd` and
`kubernetes_namespace.argocd`, review the plan before applying this change:
Terraform may uninstall the release and delete its namespace. First ensure the
existing dev Argo CD instance, if any, does not own workloads that must remain.
Do not apply a plan that destroys KEDA, its CRDs, the AWS Load Balancer
Controller, Pod Identity, or dev application Deployments.

## FinOps Tags

Terraform-managed AWS resources receive `Owner`, `ManagedBy=Terraform`,
`Environment=dev`, `CostCenter`, and `Project=fintech-platform`. Future
application manifests should use Kubernetes labels such as `app.kubernetes.io/part-of`,
`app.kubernetes.io/managed-by`, `environment`, `owner`, and `cost-center`.
Activate AWS cost-allocation tag keys in Billing/Cost Management.

## Dev Deployment Flow

The source repository's [`deploy-dev.yaml`](https://github.com/qzee-dev/fintech-platform/blob/main/.github/workflows/deploy-dev.yaml)
workflow is manually dispatched. Choose `list` to see successful release runs,
then run `deploy` with the selected release run ID(s). The workflow validates
the release metadata and ECR digest, assumes the dev deployment role, verifies
that `deployment/<service>` already exists in namespace `dev`, updates its
image to the immutable `repository@sha256:digest`, waits for rollout, and
checks the deployed digest and ready replicas.

This workflow does not create Deployments or apply the dev Helm values from the
manifest repository. Bootstrap the dev Deployments before the first release.
Configure `EKS_CLUSTER_NAME`, `AWS_ACCOUNT_ID`, and `AWS_ROLE_ARN` in the
source repository's `dev` GitHub Environment. Keep its AWS role limited to
ECR image reads, EKS discovery, and the required Kubernetes permissions for
namespace `dev`. The worker nodes must also be able to pull from ECR.

Staging and production promotion contracts are documented in their respective
environment READMEs. Their Argo CD instances and application manifests are
separate from this manual dev deployment process.

## Ingress and Shared Add-ons

The root composes independently selected add-ons through
`modules/platform`. Configure `enable_keda`, `enable_cert_manager`,
`enable_route53_dns01`, `enable_monitoring`, `enable_frontend`, and
`enable_argocd` independently in local tfvars. `ingress_controller` selects
one controller; NLB-backed controllers use
`ingress_load_balancer_scheme` (`internal` or `internet-facing`). ALB mode
requires an ACM certificate ARN. Selecting ingress automatically enables the
AWS Load Balancer Controller and EKS Pod Identity Agent. Terraform checks
required DNS, certificate, and Grafana values before installation.

The dev root selects one dedicated controller module using
`ingress_controller`. Its default is `f5-nginx`; supported values are `envoy`,
`nginx`, `alb`, and `f5-nginx`. The selected module lives under
[`../modules/`](../modules/) and creates routes for `app.<suffix>`,
`grafana.<suffix>`, and `prometheus.<suffix>`.

Each controller module uses `common` for cert-manager, optional Route 53
DNS-01 Pod Identity, kube-prometheus-stack, Grafana, Prometheus, and the sample
frontend. The AWS Load Balancer Controller is owned once by the dev base root
and is a prerequisite for AWS-backed load-balancer Services. The ALB ingress
module creates ALB routes and reuses that controller; it does not install a
second copy.

Provide the DNS suffix and a Grafana password of at least 16 characters. For
DNS-01, supply a public authoritative Route 53 zone ID and operations email;
the ACME staging endpoint is the default. For ALB, provide an ACM certificate
covering all three hostnames. The default ALB scheme is internal.

Each root uses static Terraform module sources and `count` to instantiate only
the selected controller. When changing controller from a previously applied
configuration, review the plan carefully: module addresses changed from the
old `module.selected_ingress` address. Migrate existing Terraform state
deliberately if the plan proposes replacing resources that should remain.

The separate [`terraform/ingress-dns01/`](./terraform/ingress-dns01/) root is
an alternative standalone ingress-nginx plus cert-manager installation. It
has its own Terraform state and manifests. Do not operate it alongside the
selected module if both would manage the same controller, cert-manager,
ClusterIssuer, or Pod Identity association; migrate ownership deliberately.

### Standalone ingress-dns01 root

Use this root only when intentionally managing the standalone ingress-nginx
setup rather than the selected-controller module. It installs ingress-nginx
behind an internal AWS Network Load Balancer (NLB) and cert-manager with a
Route 53 DNS-01 issuer. It does not configure Argo CD; Argo CD is installed
only in staging and production.

The standalone Terraform configuration is in
[`terraform/ingress-dns01/`](./terraform/ingress-dns01/). It installs
ingress-nginx and cert-manager, creates an EKS Pod Identity role for
cert-manager, and limits Route 53 record changes to the hosted zone you
provide. The issuer and sample service routes are in
[`terraform/ingress-dns01/manifests/`](./terraform/ingress-dns01/manifests/).

### Prerequisites

- The existing EKS cluster is active, reachable by the Terraform runner, and
  has the EKS Pod Identity Agent and AWS Load Balancer Controller installed.
  The dev stack in `terraform/` installs these add-ons.
- The AWS Load Balancer Controller IAM permissions support NLB provisioning.
- Provide the Route 53 hosted zone ID and DNS suffix for certificate issuance.
  For publicly trusted Let's Encrypt certificates, the DNS-01 record must be
  written to a **public authoritative Route 53 zone**. The app endpoints can
  still be internal; DNS-01 does not expose the services.
- Internal clients need DNS records in a private hosted zone (or equivalent
  split-horizon DNS) pointing the service hostnames at the ingress NLB. These
  records are separate from the public DNS-01 validation records. Create or
  manage those service records after the NLB is provisioned.
- Choose hostnames beneath the DNS suffix configured for the issuer, for
  example `grafana.dev.example.com`, `prometheus.dev.example.com`, and
  `app.dev.example.com`.

This option provisions an internal NLB, but public DNS validation requires a
public DNS zone. If you have only private DNS, choose an internal CA or another
certificate authority that supports private DNS validation.

### Install the standalone controller

Use the separate directory as its own Terraform root; do not merge its state
with `terraform/`. Supply the existing cluster name and a Route 53 hosted zone
ID through a local ignored tfvars file or `TF_VAR_*` environment variables.
Configure the DNS suffix separately in the ClusterIssuer manifest. For example:

```hcl
cluster_name    = "your-existing-dev-cluster"
route53_zone_id = "Z0123456789EXAMPLE"
```

Then run:

```sh
cd k8s/dev/terraform/ingress-dns01
terraform init
terraform plan
terraform apply
```

The controller chart versions are pinned in `variables.tf`; review and update
them through the normal dependency review process. After apply, get the
internal NLB hostname with:

```sh
kubectl -n ingress-nginx get service ingress-nginx-controller
```

Create internal DNS records for each service hostname pointing to that NLB.
Use your DNS platform's supported alias/CNAME behavior for the NLB hostname.

### Issue a certificate and route services

1. Copy `manifests/cluster-issuer.yaml.example` to a working manifest, replace
   the example hosted-zone ID, region, and email, then apply it. Use the
   Let's Encrypt staging endpoint first to avoid production rate limits; switch
   to production after validation.
2. Update `manifests/service-ingresses.yaml.example` with the actual service
   namespaces, Service names, and ports, then apply it. It demonstrates
   Grafana, Prometheus, and the frontend.
3. Verify each certificate becomes `Ready`, test the URLs from an authorized
   internal network, and retain authentication and network restrictions for
   Prometheus, Grafana, and the frontend.

The sample service names and ports are placeholders because this repo does not
define the Prometheus, Grafana, or frontend workloads. Each Ingress and its
TLS Secret must be in the same namespace as its backend Service; the example
uses a separate wildcard certificate Secret in each workload namespace. Keep
this dev ingress configuration limited to dev services. Argo CD is intended
for staging and production only and remains configured by those environments'
Terraform roots; do not add a dev Argo CD Ingress here.

### Trade-offs

This option gives cert-manager control of Kubernetes TLS Secrets and lets one
ingress controller route multiple hostnames through one NLB. It also adds
another controller and a separate Terraform state to operate. The existing
ALB + ACM configuration is simpler if ACM-managed certificates meet the
requirement.
