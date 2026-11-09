# Fintech Platform GitOps and Infrastructure

This repository contains shared ECR infrastructure and Kubernetes platform
bootstrap configuration. Application Argo CD manifests will be added separately.

## Components

- [`Ecr-Repo`](Ecr-Repo/README.md) creates immutable `fintech-platform/<service>`
	repositories in `us-east-1` and one OIDC release-publisher role for
	`qzee-dev/fintech-platform` on `develop`.
- [`k8s/dev/terraform`](k8s/dev/terraform) configures add-ons on an existing dev
	EKS cluster: Pod Identity, AWS Load Balancer Controller, KEDA, and Argo CD. It
	does not create the EKS cluster itself.
- `k8s/staging` and `k8s/production` are the reserved GitOps manifest locations.
	Promotion workflows expect service values files under those directories and
	Argo CD applications named `staging-<service>` and `production-<service>`.

## Release and Promotion Flow

1. The fintech release workflow builds/scans a service image, pushes an
	 immutable service-version-commit tag, captures its digest, and uploads
	 release metadata.
2. The dev workflow deploys the selected digest directly to the `dev`
	 namespace. Once Argo CD manages dev workloads, switch that step to GitOps
	 promotion to avoid Argo CD reverting direct `kubectl` changes.
3. Staging and production promotion workflows update the relevant GitOps values
	 file, commit it, and request an Argo CD sync.

## Required FinOps Tags

Use the keys `Owner`, `ManagedBy`, `Environment`, `CostCenter`, and `Project` on
AWS resources. Add `Service` and `Component` where applicable. ECR repositories
use `Environment=shared`; dev platform resources use `Environment=dev`; staging
and production manifests must use their respective environment values. The
finance-approved `CostCenter` value is required input, not a placeholder to
deploy.