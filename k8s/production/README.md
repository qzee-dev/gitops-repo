# Production GitOps Contract

Application manifests will be added later. The fintech production workflow
expects one values file per service at:

```text
k8s/production/<service>/values.yaml
```

The file must contain quoted `tag` and `digest` values for the workflow to
update. The image repository is
`<account>.dkr.ecr.us-east-1.amazonaws.com/fintech-platform/<service>`; the
workflow validates the release metadata and digest before syncing Argo CD
application `production-<service>`. Protect the GitHub `production` Environment
with the required approval reviewers.

Production AWS resources must use `Environment=production` and the
finance-approved `CostCenter`, plus `Owner`, `ManagedBy`, and
`Project=fintech-platform`. ALB-backed services must include an
`alb.ingress.kubernetes.io/tags` annotation with `ManagedBy=AWSLoadBalancerController`.
Kubernetes objects should also carry matching owner/environment/cost-center
labels. Activate AWS cost-allocation tag keys in Billing/Cost Management.

Configure these GitHub Actions variables in the `production` Environment:
`GITOPS_REPOSITORY` (`owner/repo`), `GITOPS_REPOSITORY_NAME` (repo name), and
`ARGOCD_SERVER` (hostname only, without `https://`). Configure secrets
`AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`, `ARGOCD_AUTH_TOKEN`, `GH_APP_ID`, and
`GH_APP_PRIVATE_KEY`. The GitOps repository must be accessible to the GitHub
App and, with the current token setup, share the source repository owner.

The workflow uses a GitHub-hosted runner. If `ARGOCD_SERVER` resolves to the
dev stack's internal ALB, the runner cannot reach it; use a VPC-connected
self-hosted runner or provide a deliberately reachable, secured Argo CD endpoint.
