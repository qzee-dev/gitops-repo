# Kubernetes platform

This directory configures add-ons and ingress on existing EKS clusters. It
does not create clusters, VPCs, or worker nodes.

## Architecture

```mermaid
flowchart TD
    Dev["k8s/dev/terraform"] --> DevPlatform["Platform call<br/>dev inputs"]
    Staging["k8s/staging/terraform"] --> StagePlatform["Platform call<br/>staging inputs"]
    Production["k8s/production/terraform"] --> ProdPlatform["Platform call<br/>production inputs"]

    Dev --> DevState["Dev S3 state"]
    Staging --> StageState["Staging S3 state"]
    Production --> ProdState["Production S3 state"]

    DevPlatform --> DevResources["Enabled add-ons<br/>+ 0 or 1 ingress"]
    StagePlatform --> StageResources["Enabled add-ons<br/>+ 0 or 1 ingress"]
    ProdPlatform --> ProdResources["Enabled add-ons<br/>+ 0 or 1 ingress"]
    DevResources --> DevCluster["Existing dev EKS"]
    StageResources --> StageCluster["Existing staging EKS"]
    ProdResources --> ProdCluster["Existing production EKS"]

    PlatformCode["Shared modules/platform source"] -.-> DevPlatform
    PlatformCode -.-> StagePlatform
    PlatformCode -.-> ProdPlatform
    Charts["modules/charts source"] -.-> DevResources
    Charts -.-> StageResources
    Charts -.-> ProdResources
```

Each root passes environment-specific values to `modules/platform`. That
composition module enables add-ons and at most one selected ingress. Focused
modules under `modules/addons/` and the ingress modules implement those
capabilities. Shared Helm charts live under `modules/charts/`.

Modules are code reuse, not state boundaries. Every resource created by a
child module is stored in the state of the environment root that called it.
Keep each cluster resource under one Terraform owner.

## Environment profiles

| Environment | Ingress default | Argo CD |
| --- | --- | --- |
| Dev | `f5-nginx` | Disabled by default; dev application deployments use the manual release workflow |
| Staging | `alb` | Enabled |
| Production | `envoy` | Enabled |

The ingress input accepts `none`, `envoy`, `nginx`, `f5-nginx`, or `alb`.
Add-on flags (KEDA, cert-manager, Route 53 DNS-01, monitoring, frontend, and
Argo CD) are configured separately in each root's local tfvars or through
`TF_VAR_*`. The defaults differ by environment; see its README and
`variables.tf`.

## Derived dependencies and behavior

`modules/platform/locals.tf` derives these dependencies:

- The AWS Load Balancer Controller is installed if explicitly enabled, if
  Argo CD is enabled, or if an ingress other than `none` is selected.
- The EKS Pod Identity Agent is installed if explicitly enabled, if the AWS
  Load Balancer Controller is needed, or if Route 53 DNS-01 is enabled.

These are dependencies of the current integrations. ALB routes use the AWS
Load Balancer Controller; the current Envoy, NGINX, and F5 NGINX modules also
request AWS-managed NLBs through Kubernetes Services. They do not attach to
an externally managed shared NLB.

ALB ingress uses an ACM certificate. DNS-01 TLS for NLB-backed ingress
requires cert-manager, Route 53 configuration, and an operations email.
Application DNS records are managed separately from ACME validation records.
Review plans carefully when disabling an add-on or changing ingress: with
`count`, disabling a module removes its resources from that environment's
configuration.

## Using a network-owned shared NLB

**This is not supported by the current Terraform configuration.** There is no
setting that both turns off the AWS Load Balancer Controller and keeps the
current ingress modules functional:

- Setting `enable_aws_load_balancer_controller = false` does not disable it
  while `ingress_controller != "none"` or `enable_argocd = true`; the
  dependency is derived in `modules/platform/locals.tf`.
- Setting `ingress_controller = "none"` removes the platform-managed
  application ingress. It does not attach that ingress to an existing NLB.
- Envoy, ingress-nginx, and F5 NGINX currently request a new NLB using a
  Kubernetes `LoadBalancer` Service. The `alb` option creates ALB Ingress
  resources reconciled by the AWS Load Balancer Controller.
- Staging and production Argo CD also currently expose their server through
  an AWS-LBC-managed ALB. Disabling the controller requires redesigning that
  endpoint too, or disabling Argo CD.

### Intended cross-environment scenario

The shared NLB belongs to the network/shared-infrastructure owner. Each
environment remains isolated: its Terraform root and state manage its own
cluster add-ons, ingress gateway, Kubernetes Services, and application routes.
The shared network layer manages the NLB listeners and a distinct target group
for each environment. Traffic reaches the environment's ingress gateway, and
that gateway routes to services in only its own cluster.

```mermaid
flowchart LR
    Clients["Clients / DNS"] --> SharedNLB["Network-owned shared NLB"]
    SharedNLB --> DevTG["Dev listener / target group"]
    SharedNLB --> StageTG["Staging listener / target group"]
    SharedNLB --> ProdTG["Production listener / target group"]

    DevTG --> DevIngress["Dev ingress gateway<br/>dev cluster"]
    StageTG --> StageIngress["Staging ingress gateway<br/>staging cluster"]
    ProdTG --> ProdIngress["Production ingress gateway<br/>production cluster"]

    DevTerraform["Dev Terraform root/state"] --> DevIngress
    StageTerraform["Staging Terraform root/state"] --> StageIngress
    ProdTerraform["Production Terraform root/state"] --> ProdIngress

    DevIngress --> DevServices["Dev services"]
    StageIngress --> StageServices["Staging services"]
    ProdIngress --> ProdServices["Production services"]
```

The diagram shows the desired ownership and traffic separation, not a feature
already implemented here. A single NLB does not route on HTTP hostnames like
an ALB. The network team and platform owners must choose how traffic selects
an environment (for example, separate listener ports, or a separately
designed shared Layer 7 proxy), and define TLS termination/SNI, target type,
health checks, security rules, DNS, and target registration/removal. Do not
assume DNS hostnames alone select separate NLB target groups.

### Changes required before using this design

Implement and test the integration before changing environment flags:

1. Agree with the network owner on the shared NLB contract: environment
   selection mechanism (listener ports or Layer 7 routing), target groups,
   target type, health checks, TLS/certificate termination, security rules,
   DNS, and ownership of target registration as nodes or pods change.
2. Replace each selected ingress's AWS-created `LoadBalancer` Service with
   an integration to its environment's shared-NLB target group. The target
   registration method must not depend on the AWS Load Balancer Controller
   if that controller is to be removed. `TargetGroupBinding` does not meet
   that requirement because AWS Load Balancer Controller reconciles it.
3. Replace ALB Ingress resources where needed. In particular, staging uses
   ALB for application ingress and staging/production Argo CD currently use
   ALB. Each must use the shared-NLB path or be disabled before AWS Load
   Balancer Controller can be removed from that environment.
4. Change `modules/platform/locals.tf` so the AWS Load Balancer Controller is
   required only by remaining integrations that actually use it. Keep it
   enabled in any environment that still has AWS-LBC-managed resources.
5. Test each environment and review its own Terraform state and plan. Confirm
   the network stack remains the only owner of the shared NLB and that plans
   preserve ingress gateways, healthy targets, Argo CD (if retained), and
   application endpoints.

Only after that implementation exists should an environment use a
non-`none` ingress with `enable_aws_load_balancer_controller = false`. Until
then, that setting does not avoid installation; setting `ingress_controller =
"none"` avoids the current ingress path but leaves no Terraform-managed
application ingress. The environment READMEs describe each environment's
part in this proposed design.

## State and generated files

All three platform roots use separate S3 state keys configured through each
root's ignored `backend.hcl`: `dev/terraform.tfstate`,
`staging/terraform.tfstate`, and `production/terraform.tfstate`. Never
initialize an environment with another environment's backend key. When
migrating existing dev local state, back it up and use the procedure in the
[runbook](../RUNBOOK.md#moving-existing-state-to-s3). Terraform's
`.terraform/` directory, including `modules/modules.json`, is local generated
cache metadata; it is not state or source configuration.

The dev tree also contains `dev/terraform/ingress-dns01/`, a separate
standalone ingress-nginx/cert-manager Terraform root. It has its own local
state and is an alternative to the standard dev platform ingress, not an
additional module in `modules/platform`. Do not run both roots against the
same ingress, cert-manager, or Pod Identity resources.

For initialization, plans, applications, and the one-time dev state address
migration, see [`../RUNBOOK.md`](../RUNBOOK.md).
