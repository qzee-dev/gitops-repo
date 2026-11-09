# Production GitOps Location

Application manifests are maintained in
`qzee-dev/fintech-enterprise-gitops-manifest`, not in this infrastructure
repository. The fintech production workflow updates:

```text
enterprise-gitops/environments/production/<service>/values.yaml
```

The workflow writes the resolved ECR repository, immutable image tag, and
verified digest before syncing Argo CD application `production-<service>`.
Protect the GitHub `production` Environment with required approval reviewers.

Production AWS resources must use `Environment=production` and the
finance-approved `CostCenter`, plus `Owner`, `ManagedBy`, and
`Project=fintech-platform`. ALB-backed services must include an
`alb.ingress.kubernetes.io/tags` annotation with `ManagedBy=AWSLoadBalancerController`.
Kubernetes objects should also carry matching owner/environment/cost-center
labels. Activate AWS cost-allocation tag keys in Billing/Cost Management.

Configure these GitHub Actions variables in the source repository's
`production` Environment:
`GITOPS_REPOSITORY=qzee-dev/fintech-enterprise-gitops-manifest`,
`GITOPS_REPOSITORY_NAME=fintech-enterprise-gitops-manifest`, and
`ARGOCD_SERVER` (hostname only, without `https://`). Configure secrets
`AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`, `ARGOCD_AUTH_TOKEN`, `GH_APP_ID`, and
`GH_APP_PRIVATE_KEY`. The GitOps repository must be accessible to the GitHub
App. The account ID must be the 12-digit AWS account that owns the ECR
repositories.

The workflow uses a GitHub-hosted runner. If `ARGOCD_SERVER` resolves to the
dev stack's internal ALB, the runner cannot reach it; use a VPC-connected
self-hosted runner or provide a deliberately reachable, secured Argo CD endpoint.
