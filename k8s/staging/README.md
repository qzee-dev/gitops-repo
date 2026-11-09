# Staging GitOps Contract

Application manifests will be added later. The fintech staging workflow expects
one values file per service at:

```text
k8s/staging/<service>/values.yaml
```

The file must contain quoted `tag` and `digest` values for the workflow to
update. The image repository is
`<account>.dkr.ecr.us-east-1.amazonaws.com/fintech-platform/<service>`; the
workflow promotes the immutable release tag and verifies the digest before
syncing Argo CD application `staging-<service>`.

Staging AWS resources must use `Environment=staging` and the finance-approved
`CostCenter`, plus `Owner`, `ManagedBy`, and `Project=fintech-platform`. For
ALB-backed services, include an `alb.ingress.kubernetes.io/tags` annotation;
set `ManagedBy=AWSLoadBalancerController`. Kubernetes objects should also carry
the corresponding owner/environment/cost-center labels.

Configure these GitHub Actions variables in the `staging` Environment:
`GITOPS_REPOSITORY` (`owner/repo`), `GITOPS_REPOSITORY_NAME` (repo name), and
`ARGOCD_SERVER` (hostname only, without `https://`). Configure secrets
`AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`, `ARGOCD_AUTH_TOKEN`, `RELEASE_APP_ID`, and
`RELEASE_APP_PRIVATE_KEY`. The GitOps repository must be accessible to the
GitHub App and, with the current token setup, share the source repository owner.

The workflow uses a GitHub-hosted runner. If `ARGOCD_SERVER` resolves to the
dev stack's internal ALB, the runner cannot reach it; use a VPC-connected
self-hosted runner or provide a deliberately reachable, secured Argo CD endpoint.
