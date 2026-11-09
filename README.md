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
	EKS cluster: Pod Identity, AWS Load Balancer Controller, KEDA, and Argo CD. It
	does not create the EKS cluster itself.
- `k8s/staging` and `k8s/production` are reserved for future infrastructure
	configuration; application values live in the enterprise manifest repository.
	Promotion workflows update `enterprise-gitops/environments/<environment>/<service>/values.yaml`
	there, and Argo CD applications are named `<environment>-<service>`.

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