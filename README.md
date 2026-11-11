# Fintech Platform GitOps and Infrastructure

This repository contains shared ECR infrastructure and Kubernetes platform
bootstrap configuration. Application Helm values and Argo CD sources are
maintained in `qzee-dev/fintech-enterprise-gitops-manifest`.

For repository responsibilities, Terraform operation, prerequisites, and
deployment handoffs, see the [infrastructure runbook](RUNBOOK.md).

## Components

- [`Ecr-Repo`](Ecr-Repo/README.md) creates immutable `fintech-platform/<service>`
	repositories in `us-east-1` and one OIDC release-publisher role for
	`qzee-dev/fintech-platform` on `develop`.
- [`k8s/dev/terraform`](k8s/dev/terraform) configures add-ons on an existing dev
	EKS cluster: Pod Identity, AWS Load Balancer Controller, KEDA, and the
	selected application ingress module. Dev application releases are deployed
	manually by digest; this root does not install Argo CD.
- [`k8s/README.md`](k8s/README.md) documents the current ingress-controller model,
	shared add-ons, and the per-environment controller selection design.
- [`k8s/staging/terraform`](k8s/staging/terraform) and
	[`k8s/production/terraform`](k8s/production/terraform) install the same
	required platform add-ons and the intended Argo CD instances on existing
	environment clusters. Each root independently selects one application
	ingress module; the AWS Load Balancer Controller remains a shared platform
	dependency for Argo CD ALBs and AWS-backed Services.
- Application values live in the enterprise manifest repository. Separate
	staging and production ApplicationSets generate
	`<environment>-<service>` applications on their respective clusters.
	Dev releases use the source repository's manual deployment workflow. See
	[RUNBOOK.md](RUNBOOK.md) for deployment and environment responsibilities.

## Kubernetes architecture overview

The platform is organized as a shared base layer plus an environment-specific ingress layer:

- `k8s/modules/platform` composes the cluster-wide capabilities that are shared across environments
- `k8s/modules/<ingress-controller>` contains the selected ingress implementation for that environment
- each environment root chooses one ingress controller through `ingress_controller`
- AWS Load Balancer Controller is not optional in the current design when an environment exposes workload traffic through AWS-managed load balancers

The environment policy is:

- Dev: `f5-nginx`
- Staging: `alb`
- Production: `envoy`

This keeps the shared AWS integration stable while allowing each cluster to run its own supported ingress pattern. For a complete operational explanation, see [k8s/README.md](k8s/README.md) and [RUNBOOK.md](RUNBOOK.md).

## Release and Promotion Flow

1. The fintech release workflow builds/scans a service image, pushes an
	 immutable service-version-commit tag, captures its digest, and uploads
	 release metadata.
2. The dev workflow deploys the selected digest directly to the `dev`
	 namespace. Dev values in the enterprise manifest repository are not
	 watched by Argo CD.
3. Staging and production promotion workflows update the relevant values file
	 in `qzee-dev/fintech-enterprise-gitops-manifest`, commit it, and verify
	 Argo CD sync.

Configure `GITOPS_REPOSITORY=qzee-dev/fintech-enterprise-gitops-manifest` and
`GITOPS_REPOSITORY_NAME=fintech-enterprise-gitops-manifest` in the source
repository's staging and production GitHub Environments. The GitHub App must
have contents-write access to that repository.

## Required FinOps Tags

Use the keys `Owner`, `ManagedBy`, `Environment`, `CostCenter`, and `Project` on
AWS resources. Add `Service` and `Component` where applicable. ECR repositories
use `Environment=shared`; dev platform resources use `Environment=dev`; staging
and production manifests must use their respective environment values. The
finance-approved `CostCenter` value is required input, not a placeholder to
deploy.