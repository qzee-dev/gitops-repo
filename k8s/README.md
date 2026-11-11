# Kubernetes platform and ingress controller implementation

This directory contains the Terraform and module structure for the Kubernetes platform add-ons and the environment-specific ingress controller choice.

## Architecture at a glance

This repository does not create a cluster or VPC. It assumes each environment already has an EKS cluster and AWS networking, then bootstraps the platform pieces that sit on top of it.

The design is intentionally split into two layers:

- Shared platform layer: Pod Identity, AWS Load Balancer Controller, cert-manager, monitoring, KEDA, sample frontend, and optional Argo CD
- Environment-specific ingress layer: exactly one ingress controller per environment (`envoy`, `nginx`, `f5-nginx`, or `alb`)

The key idea is that a cluster can keep one shared AWS integration stack while each environment chooses the application-facing ingress it wants to run. In practice, the AWS Load Balancer Controller remains a shared platform dependency even when the environment uses an NLB-backed ingress because Kubernetes Services and ingress resources still depend on AWS load balancer reconciliation.

### Shared composition pattern

Each environment root calls the shared platform module in `k8s/modules/platform`:

- `module "platform"` is the common composition entrypoint
- it evaluates `local.needs_aws_load_balancer_controller` and `local.needs_pod_identity_agent`
- it installs the shared add-ons only when required
- it leaves the application ingress choice to the environment root via `ingress_controller`

### Why the AWS Load Balancer Controller is always in the platform path

The AWS Load Balancer Controller is required for this architecture because it is the AWS integration that manages Kubernetes Service and Ingress resources backed by AWS load balancers.

- ALB mode: required for AWS ALB Ingress reconciliation
- NLB mode (`envoy`, `nginx`, `f5-nginx`): still required because the controller provisions the AWS NLB that fronts the ingress Service
- Argo CD: required because its ALB is created through the same AWS controller integration

That is why the module auto-enables it when an ingress is selected or when Argo CD is enabled, instead of treating it as a purely ALB-only feature.

## Goal

The platform is designed so that each environment selects its own application ingress controller explicitly instead of forcing all environments to use the same controller.

Supported controller choices:

- `envoy` – Envoy Gateway + Gateway API
- `nginx` – ingress-nginx
- `f5-nginx` – F5 NGINX Ingress
- `alb` – AWS Load Balancer Controller

The AWS Load Balancer Controller is a separate cluster integration. It is owned once by dev's base add-ons and by the Argo CD platform module in staging and production. It remains installed where needed for Argo CD ALBs and AWS-backed LoadBalancer Services; choosing Envoy, NGINX, or F5 does not remove that shared infrastructure add-on.

## Environment controller policy

Each environment root independently selects a controller:

- Dev: `f5-nginx`
- Staging: `alb`
- Production: `envoy`

The selection is controlled in each environment Terraform root and resolves to the matching dedicated module under `k8s/modules/`.

## Add-on and ingress selection

Each environment root calls the shared `modules/platform` composition module.
Choose add-ons independently in that environment's ignored `terraform.tfvars`
file, then select at most one ingress implementation:

```hcl
enable_keda                  = true
enable_cert_manager          = true
enable_route53_dns01         = true
enable_monitoring            = true
enable_frontend              = true
enable_argocd                = false
ingress_controller           = "f5-nginx"
ingress_load_balancer_scheme = "internet-facing"
```

Supported add-ons are the EKS Pod Identity Agent, AWS Load Balancer
Controller, KEDA, cert-manager, monitoring, the sample frontend, and Argo CD.
`ingress_controller` accepts `none`, `envoy`, `nginx`, `f5-nginx`, or `alb`.
Selecting an ingress automatically enables the AWS Load Balancer Controller
and Pod Identity Agent: the NLB-backed controllers need AWS load-balancer
provisioning, while ALB Ingresses are reconciled by that same controller.
Argo CD also requires the AWS Load Balancer Controller for its ALB.

Envoy Gateway, ingress-nginx, and F5 NGINX expose their Service through an
NLB; `ingress_load_balancer_scheme` chooses `internal` or `internet-facing`.
ALB mode creates ALB Ingress resources and requires
`ingress_alb_certificate_arn` for ACM TLS. NLB-based TLS is optional and
requires cert-manager plus Route 53 DNS-01 values. Application DNS records
must be created separately; DNS-01 only manages ACME validation records.

Each root owns a separate Terraform state. Do not initialize one environment
with another environment's backend key or let multiple roots manage the same
cluster add-on. Review plans before changing selections, especially when
switching ingress controllers.

## Directory structure

```text
k8s/
├── README.md
├── dev/
│   └── terraform/
├── staging/
│   └── terraform/
├── production/
│   └── terraform/
└── modules/
    ├── common/
    ├── aws-alb-controller/
    ├── envoy-gateway/
    ├── f5-nginx-ingress/
    ├── ingress-nginx/
    └── ingress-platform/
```

## Modules

### common

Shared add-ons used across ingress implementations:

- cert-manager
- Route 53 DNS-01 IAM via EKS Pod Identity
- kube-prometheus-stack
- Grafana
- Prometheus
- sample frontend deployment

### aws-alb-controller

Creates ALB-backed sample routes using the shared routing chart. It reuses the AWS Load Balancer Controller already owned by the environment platform; it does not install a second copy.

### envoy-gateway

Installs Envoy Gateway and creates Gateway API resources for the sample frontend and monitoring endpoints.

### f5-nginx-ingress

Installs F5 NGINX Ingress and creates Ingress resources with the matching class name and TLS handling.

### ingress-nginx

Installs community ingress-nginx as an explicit controller option, keeping the older controller available alongside newer alternatives.

### ingress-platform

Legacy/shared routing chart used by the controller modules. It contains the shared route templates, certificate logic, and helper manifests.

## Add-ons currently present

The platform currently includes the following add-ons and capabilities:

- AWS EKS Pod Identity integration
- cert-manager for TLS certificate automation
- Route 53 access for DNS-01 certificate validation
- kube-prometheus-stack for monitoring
- Grafana and Prometheus endpoints
- sample frontend service deployment
- optional ingress controller selection by environment
- AWS ALB Controller support for ALB routing
- Envoy Gateway API support
- ingress-nginx and F5 NGINX options

## Example implementation pattern

Each environment root selects one module by changing the value of `ingress_controller`:

```hcl
ingress_controller = "envoy"
```

or

```hcl
ingress_controller = "alb"
```

or

```hcl
ingress_controller = "f5-nginx"
```

Each environment declares a module block with a literal source path for each supported controller and uses `count` to instantiate only the selected module. Terraform module sources cannot be computed from an input variable. For example:

```hcl
module "ingress_envoy" {
    count  = var.ingress_controller == "envoy" ? 1 : 0
    source = "../../modules/envoy-gateway"
}
```

This pattern keeps the architecture explicit: one selected application ingress module per environment, with shared AWS load-balancer infrastructure managed separately.

## Required values

Each environment should define the following values before apply:

- `cluster_name`
- `aws_region`
- `vpc_id`
- `domain_suffix`
- `route53_zone_id`
- `grafana_admin_password`
- `ingress_controller`
- `ingress_load_balancer_scheme`
- `enable_keda`, `enable_cert_manager`, `enable_route53_dns01`
- `enable_monitoring`, `enable_frontend`, `enable_argocd`
- `acme_email` (when using cert-manager)
- `acme_server` (optional override)
- `ingress_alb_certificate_arn` (for ALB mode)

## Notes

- Run `terraform fmt -check`, `terraform validate`, and review `terraform plan` from each environment root before applying.
- The application routing design is intentionally one selected ingress module per environment; the shared AWS Load Balancer Controller may remain installed as infrastructure.
- This makes it easier to operate, troubleshoot, and switch an environment to a different controller without breaking the rest of the platform.

## Next steps

1. Set the controller for each environment in the environment-specific `terraform.tfvars` files.
2. Confirm Route 53 hosted zone and ACM certificate values where needed.
3. Apply the environment Terraform roots in the normal deployment order.
4. Validate the sample frontend, Grafana, and Prometheus endpoints through the selected controller.
