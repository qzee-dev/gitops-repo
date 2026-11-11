# Kubernetes platform and ingress controller implementation

This directory contains the Terraform and module structure for the Kubernetes platform add-ons and the environment-specific ingress controller choice.

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
- `acme_email` (when using cert-manager)
- `acme_server` (optional override)
- `ingress_alb_certificate_arn` (for ALB mode)
- `ingress_alb_scheme` (for ALB mode)

## Notes

- The Terraform validation was run successfully for the dev, staging, and production roots.
- The application routing design is intentionally one selected ingress module per environment; the shared AWS Load Balancer Controller may remain installed as infrastructure.
- This makes it easier to operate, troubleshoot, and switch an environment to a different controller without breaking the rest of the platform.

## Next steps

1. Set the controller for each environment in the environment-specific `terraform.tfvars` files.
2. Confirm Route 53 hosted zone and ACM certificate values where needed.
3. Apply the environment Terraform roots in the normal deployment order.
4. Validate the sample frontend, Grafana, and Prometheus endpoints through the selected controller.
