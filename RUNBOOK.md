# Infrastructure runbook

This runbook covers the three Kubernetes Terraform environments in this
repository: **dev, staging, and production**. Run one environment at a time,
from that environment's Terraform root.

The repository manages ECR infrastructure and bootstraps add-ons and ingress
on existing EKS clusters. It does not create the clusters, VPCs, worker nodes,
or application Deployments, and it is not the application source or GitOps
manifest source of truth.

## What each environment does

| Environment | Terraform root | State | Default ingress | Application delivery |
| --- | --- | --- | --- | --- |
| Dev | `k8s/dev/terraform/` | S3 key `dev/terraform.tfstate` | `f5-nginx` | The source repository's manual workflow updates an existing `Deployment` in namespace `dev` |
| Staging | `k8s/staging/terraform/` | S3 key `staging/terraform.tfstate` | `alb` | Staging Argo CD syncs the staging ApplicationSet |
| Production | `k8s/production/terraform/` | S3 key `production/terraform.tfstate` | `envoy` | Production Argo CD syncs the production ApplicationSet after approval |

Each root manages its own cluster add-ons and selected ingress through the
shared `k8s/modules/platform` code. A child module is not a separate state:
its resources belong to the environment root that called it. Never configure
two roots to manage the same cluster resource.

The release flow is:

1. [`qzee-dev/fintech-platform`](https://github.com/qzee-dev/fintech-platform)
   builds and publishes immutable images to ECR.
2. Its manual dev workflow deploys a verified image digest to an existing dev
   Deployment.
3. Its staging and production promotion workflows update values in
   [`qzee-dev/fintech-enterprise-gitops-manifest`](https://github.com/qzee-dev/fintech-enterprise-gitops-manifest).
4. Staging and production Argo CD instances sync only their respective
   ApplicationSets and clusters.

## Before you start

1. Install Terraform **1.10 or later** and confirm with `terraform version`.
   All three roots use S3's native state locking, supported from Terraform
   1.10.
2. Configure AWS credentials for the intended account and confirm the active
   identity with `aws sts get-caller-identity`.
3. Ensure that identity can read the target EKS cluster and manage the
   resources in the plan. The runner must be able to reach the EKS Kubernetes
   API for Helm and Kubernetes resources.
4. Collect the target cluster name, AWS region, VPC ID, and finance-approved
   cost center. Collect ingress domains, certificates, Route 53 details, and
   operational secrets only for the features you intend to enable.
5. Confirm the selected environment, state location, and current ownership of
   the cluster resources. Do not use another environment's variables, state,
   or credentials.

Keep credentials and secrets out of source control. The dev
`k8s/dev/terraform/terraform.tfvars` is tracked, so do not put secrets in it;
provide sensitive values through a protected runner environment or secret
store. Replace every `REPLACE_WITH_...` placeholder in dev's file and in the
staging/production examples before planning. Staging and production can use
local `terraform.tfvars` files created from their examples; those files are
ignored by Git, but must still be kept secure.

The tfvars files list the environment's infrastructure identity, add-on
selections, and ingress settings. Required infrastructure values include
`aws_region`, `cluster_name`, `vpc_id`, and the approved `cost_center`.
Ingress-enabled environments also need `ingress_domain_suffix`. Features add
their own requirements: Route 53 DNS-01 needs `route53_zone_id` and
`acme_email`; ALB application ingress needs `ingress_alb_certificate_arn`;
Argo CD needs its domain and ACM certificate ARN. Monitoring needs a
Grafana password of at least 16 characters, provided as
`TF_VAR_grafana_admin_password`, never in a tracked file.

## Run an environment

Use the procedure for exactly one environment. The examples create and apply
a saved plan so the reviewed plan is the one applied. Treat the plan file as
sensitive, do not commit it, and remove it after a successful apply.

### Dev

Dev uses the S3 key `dev/terraform.tfstate`, separate from staging and
production. Configure its backend and credentials independently.

1. Change to the dev root and create the local backend configuration:

   ```sh
   cd k8s/dev/terraform
   cp backend.hcl.example backend.hcl
   ```

2. Edit `backend.hcl` and replace the bucket placeholder with the approved
   state bucket. Set `region` to that bucket's AWS region and keep the key as
   `dev/terraform.tfstate`; do not use either staging or production key.
3. Edit the tracked `terraform.tfvars`: replace all `REPLACE_WITH_...`
   placeholders with the actual dev `cluster_name`, `vpc_id`, approved
   `cost_center`, Route 53 zone, operations email, and domain values. The
   selected F5 NGINX ingress currently needs `ingress_domain_suffix`,
   `grafana_hostname`, `prometheus_hostname`, and `kibana_hostname`. Set the
   Kibana hostname beneath the suffix and set `enable_efk = true` for the
   dev-first rollout. Set Grafana and Prometheus to full
   hostnames beneath the suffix, for example
   `grafana.dev.example.com` and `prometheus.dev.example.com` when the suffix
   is `dev.example.com`. Supply
   `TF_VAR_grafana_admin_password` from a protected secret source.
4. Initialize with the dev backend, then format-check and validate. For a new
   root with no existing state, run:

   ```sh
   terraform init -backend-config=backend.hcl
   ```

   If this root has existing local state, follow
   [Moving existing state to S3](#moving-existing-state-to-s3) before
   initializing.

   Then run:

   ```sh
   terraform fmt -check
   terraform validate
   ```

5. Create and inspect a plan:

   ```sh
   terraform plan -out=dev.tfplan
   terraform show dev.tfplan
   ```

6. Confirm the AWS account, dev cluster, state key, tags, resource changes,
   and any replacements or deletions. Apply only if the plan is expected:

   ```sh
   terraform apply dev.tfplan
   ```

7. Remove the local plan file after the apply:

   ```sh
   rm dev.tfplan
   ```

Dev Terraform does not deploy the application. For an application release,
use the source repository's manual workflow; it requires the existing dev
`Deployment` in namespace `dev`.

The dev ingress routes the frontend at `app.<ingress_domain_suffix>` and
monitoring at the configured `grafana_hostname` and
`prometheus_hostname`. Terraform creates the Kubernetes routes, not the
application DNS records. Create DNS records for these names pointing to the
F5 NGINX load balancer separately. Its `internal` scheme means the endpoints
are reachable only from networks that can access that load balancer. DNS-01
creates ACME validation records through cert-manager; it does not create the
application's A/alias/CNAME records.

### Staging

Staging uses the S3 key `staging/terraform.tfstate`. Configure its backend
separately from production.

1. Change to the staging root and create the local backend configuration:

   ```sh
   cd k8s/staging/terraform
   cp backend.hcl.example backend.hcl
   ```

2. Edit `backend.hcl` and replace the bucket placeholder with the approved
   state bucket. Set `region` to that bucket's AWS region. Keep the configured
   key as `staging/terraform.tfstate`; do not use the production key.
3. Create `terraform.tfvars` from the example and fill in the staging cluster,
   VPC, region, cost center, domains, certificates, and settings for the
   features to enable. Keep secrets secure:

   ```sh
   cp terraform.tfvars.example terraform.tfvars
   ```
4. Initialize this root with its backend, then format-check and validate:

   ```sh
   terraform init -backend-config=backend.hcl
   terraform fmt -check
   terraform validate
   ```

5. Create and inspect a plan:

   ```sh
   terraform plan -out=staging.tfplan
   terraform show staging.tfplan
   ```

6. Confirm the AWS account, staging cluster, state key, tags, and every
   replacement or deletion. Apply only the reviewed plan:

   ```sh
   terraform apply staging.tfplan
   ```

7. Remove the local plan file after the apply:

   ```sh
   rm staging.tfplan
   ```

Keep `enable_efk = false` in staging until dev has been validated and the
staging rollout is approved. Staging's example includes its intended EFK
capacity and hostname for a later enablement.

Staging's default application ingress is ALB, and staging Argo CD also uses an
AWS Load Balancer Controller-managed ALB. Argo CD syncs the staging
ApplicationSet from the GitOps manifest repository.

With monitoring and ingress enabled, staging's routes chart uses
`grafana.<ingress_domain_suffix>` and
`prometheus.<ingress_domain_suffix>`; the frontend uses
`app.<ingress_domain_suffix>`. Create DNS records for these names pointing to
the ALB separately. The ACM certificate configured for application ingress
must cover the application and monitoring hostnames. The ALB scheme is
`internal` by default, so clients need network access to it.

### Production

Production uses the separate S3 key `production/terraform.tfstate`. Use
production-specific credentials, values, and approvals.

1. Change to the production root and create the local backend configuration:

   ```sh
   cd k8s/production/terraform
   cp backend.hcl.example backend.hcl
   ```

2. Edit `backend.hcl` and replace the bucket placeholder with the approved
   state bucket. Set `region` to that bucket's AWS region. Keep the configured
   key as `production/terraform.tfstate`; do not use the staging key.
3. Create `terraform.tfvars` from the example and fill in the production
   cluster, VPC, region, cost center, domains, certificates, and settings for
   the features to enable. Keep secrets in a protected secret source:

   ```sh
   cp terraform.tfvars.example terraform.tfvars
   ```
4. Initialize this root with its backend, then format-check and validate:

   ```sh
   terraform init -backend-config=backend.hcl
   terraform fmt -check
   terraform validate
   ```

5. Create and inspect a plan:

   ```sh
   terraform plan -out=production.tfplan
   terraform show production.tfplan
   ```

6. Confirm the AWS account, production cluster, state key, tags, and every
   replacement or deletion. Obtain the required production approval; apply
   only the reviewed plan:

   ```sh
   terraform apply production.tfplan
   ```

7. Remove the local plan file after the apply:

   ```sh
   rm production.tfplan
   ```

Keep `enable_efk = false` in production until dev and staging are validated,
production capacity and costs are approved, and Elasticsearch snapshots and
restore have been tested. Production's example includes intended EFK capacity
and hostname for a later, separately approved enablement.

Production's default application ingress is Envoy, and production Argo CD uses
an AWS Load Balancer Controller-managed ALB. Argo CD syncs the production
ApplicationSet after the required promotion approval.

With monitoring and ingress enabled, production's routes chart uses
`grafana.<ingress_domain_suffix>` and
`prometheus.<ingress_domain_suffix>`; the frontend uses
`app.<ingress_domain_suffix>`. Create DNS records for these names pointing to
the Envoy ingress load balancer separately. The default load balancer scheme
is `internal`, so clients need network access to it. When DNS-01 TLS is
enabled, cert-manager requests a wildcard certificate for the configured
domain suffix, but it does not create these application DNS records.

The checked-in production tfvars example points `acme_server` at Let's Encrypt
staging. Keep that endpoint for certificate testing; change it to the
approved production ACME directory before expecting publicly trusted
certificates.

## After applying

Confirm Terraform completed successfully and that the resulting resources
match the reviewed plan. Verify the configured add-ons and ingress are healthy
in the target cluster. For staging and production, also confirm the correct
Argo CD instance is reachable and syncing only its environment's
ApplicationSet. Application delivery is separate from Terraform: dev uses
the source repository's manual workflow, while staging and production use
their GitOps promotion workflows.

## Monitoring and observability operations

Monitoring is an independent opt-in add-on. When `enable_monitoring = true`,
the environment root installs kube-prometheus-stack, Tempo, and the
OpenTelemetry Collector in namespace `monitoring`. EFK has its own flag,
namespace, storage, and lifecycle; enabling one does not enable the other.

### Data path and current limits

| Data | Source and path | Destination | Current retention/storage |
| --- | --- | --- | --- |
| Traces | service OTLP to Collector `4317` gRPC or `4318` HTTP/protobuf | Tempo, viewed in Grafana | 24 hours, local backend, 20Gi PVC |
| Metrics | service OTLP to Collector; Prometheus scrapes its exporter on `8889` every 30 seconds | Prometheus and Grafana | 15 days, 20Gi PVC |
| Logs | JSON to container stdout/stderr; Fluent Bit tails container logs | Elasticsearch and Kibana | EFK ILM deletes `logs-*` after 14 days |

The Collector and OTLP ports are internal ClusterIP services. The Collector
does not export logs: set `OTEL_LOGS_EXPORTER=none` and write structured JSON
to stdout/stderr for Fluent Bit. Services should set `service.name`,
`service.version`, `service.namespace=fintech-platform`, the actual
`deployment.environment.name`, and `service.instance.id` resource attributes.
See the [observability contract](docs/OBSERVABILITY.md) for per-service
instrumentation and data-hygiene requirements.

Tempo's PVC persists across a pod replacement, but local storage is not a
backup or HA design. No Tempo or Prometheus snapshot schedule is configured.
Before production reliance, approve recovery procedures and a durable
object-storage/HA design for traces. The monitoring module provides chart
defaults and the Tempo datasource; it does not define application-specific
dashboards, alert rules, or Alertmanager notification receivers. Configure
and test notification routes before relying on alerts.

### Enable and deploy

1. In the intended environment tfvars, set `enable_monitoring = true`. Check
   the environment README and confirm capacity for Prometheus (20Gi PVC),
   Grafana (10Gi PVC), Tempo (20Gi PVC), and two Collector replicas (100m
   CPU/128Mi memory requests and 500m CPU/512Mi memory limits each). Confirm
   the default StorageClass can provision the claims.
2. Provide `TF_VAR_grafana_admin_password` from a protected secret source. It
   must be at least 16 characters. Do not put it in tracked tfvars or plans.
   Terraform marks it sensitive in output, but the Helm release and Terraform
   state still contain sensitive configuration; restrict state access.
3. Use the environment-specific S3 backend and follow that environment's
   saved-plan procedure above. Run `terraform fmt -check`, `terraform
   validate`, create and inspect a saved plan, then apply only that plan.
   Check for the expected Helm releases, PVCs, monitoring routes, and any
   unexpected replacements or removals.
4. Monitoring routes are only created when monitoring and ingress are both
   enabled. Terraform does not create DNS records. Create Grafana and
   Prometheus records separately and restrict access to authorized networks.
   Tempo and the Collector have no public routes. Browser telemetry is not
   wired to the internal Collector; do not expose it without a separate
   authenticated and rate-limited design.

### Verify the stack

Run checks using the intended cluster context:

```sh
kubectl -n monitoring get pods,svc,pvc
kubectl -n monitoring get prometheus,prometheusrule
kubectl -n monitoring get pods -o wide
```

Confirm Prometheus, Grafana, Tempo, and both Collector replicas are Ready and
the claims are Bound. If pods are pending or restarting, inspect the pod,
StorageClass, EBS CSI driver, quota, and namespace events. Inspect recent
Collector startup/export errors with:

```sh
kubectl -n monitoring logs deploy/opentelemetry-collector --all-containers=true --since=15m
```

Use the configured internal ingress or temporary local port-forwarding for
the UIs; stop port-forwards when finished and do not bind them publicly:

```sh
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Grafana's initial username is `admin`; use the password supplied through the
protected Terraform variable. Verify its Prometheus datasource and the
`Tempo` datasource at `http://tempo.monitoring.svc.cluster.local:3100`. In
Prometheus, check **Status > Targets** and verify
`opentelemetry-collector` is UP. Application metric names depend on the app
SDK and semantic-convention version; agree on them before building dashboards
or alert expressions.

For an end-to-end check, deploy an instrumented in-cluster service and make a
representative request. Then verify each independent path:

1. Find the trace in Grafana's Tempo datasource using service/resource
   attributes.
2. Confirm the Collector Prometheus target is UP and the service metrics are
   present using their agreed names.
3. Confirm the service wrote a JSON log to stdout/stderr, Fluent Bit shipped
   it, and the record is searchable in Kibana. Trace/span IDs appear only
   when the log was emitted within an active span.

Terraform success and healthy Helm pods do not prove app instrumentation,
metric naming, browser telemetry, log redaction, or alert delivery.

### Troubleshooting

| Symptom | Checks |
| --- | --- |
| Collector has no incoming data | Check app exporter errors, internal Collector DNS/port/protocol, and Collector logs. Do not use `localhost` from a workload pod. |
| Traces are missing | Check OTLP trace export, Collector/Tempo pod health, connectivity to `tempo.monitoring.svc.cluster.local:4317`, and Grafana's Tempo datasource. |
| Application metrics are missing | Check OTLP metric export, resource attributes, Prometheus target health on `8889`, then search the SDK's actual metric name. Workloads do not expose a separate scrape port here. |
| Logs are missing | Check app stdout/stderr, Fluent Bit DaemonSet/logs, its API-key Secret and CA mount, Elasticsearch health, and Kibana time range. OTLP logs are not exported. |
| Grafana/Prometheus is unreachable | Check ingress controller, route resources, DNS, TLS/ACM, and internal network access. Terraform does not create application DNS records. |
| PVCs are Pending | Check StorageClass, EBS CSI, AZ constraints, node/volume quotas, and cluster events. Do not delete claims as a first troubleshooting step. |
| Alerts have no notification | Alertmanager is enabled, but this repo does not configure an application notification receiver. Configure and test the approved receiver separately. |

### Change, upgrade, or disable

Chart versions are pinned in `k8s/modules/addons/monitoring/variables.tf` and
the platform module. Upgrade in dev first; inspect rendered changes and the
saved Terraform plan, validate datasource health and telemetry, then promote
through the staging/production approvals. Do not permanently patch
Helm-managed resources by hand. Before disabling monitoring, review the plan
and decide how required data will be retained. PVC retention is not a backup.

## EFK logging operations

The EFK add-on is an isolated stack per EKS environment: ECK manages
Elasticsearch and Kibana in the `logging` namespace, while Fluent Bit runs as
a DaemonSet and ships container logs to that environment's Elasticsearch.
Terraform currently enables this stack only in dev. Enabling it in staging or
production is a separate rollout, not a side effect of dev.

Application logs must be structured JSON written to stdout/stderr. Fluent Bit
tails those container logs, merges JSON fields, adds Kubernetes metadata, and
sends them over TLS to Elasticsearch. This is separate from OTLP traces and
metrics. The Collector does not export logs; do not set
`OTEL_LOGS_EXPORTER=otlp` or expect OTLP log records to appear in Kibana.

### Capacity and data lifecycle

| Environment | Initial status | Elasticsearch | Elasticsearch per-node resources | Kibana resources | Retention |
| --- | --- | --- | --- | --- | --- |
| Dev | Enabled for validation | 1 node × 20Gi | 2 CPU, 4Gi memory | 500m CPU, 1Gi memory | 14 days |
| Staging | Disabled | 3 nodes × 50Gi | 2 CPU, 4Gi memory | 500m CPU, 1Gi memory | 14 days |
| Production | Disabled | 3 nodes × 100Gi | 2 CPU, 4Gi memory | 500m CPU, 1Gi memory | 14 days |

An empty `elasticsearch_storage_class` uses the cluster's default
StorageClass. Fluent Bit requests 100m CPU/128Mi memory and is limited to
500m CPU/512Mi memory per cluster node. Verify available node capacity,
persistent-volume quotas, EBS limits, and cost before enabling each
environment. Elasticsearch resource requests equal its limits.

The stack applies a 14-day Elasticsearch ILM delete policy to `logs-*`
indices. This retention policy is not a backup. Terraform does not configure
an Elasticsearch snapshot repository or schedule. Before staging or
production enablement, configure snapshots to durable storage, verify a
restore into an isolated target, and obtain the relevant operational
approval. Fluent Bit captures application container logs, which may contain
sensitive data; applications must not write credentials or secrets to logs.
Kibana currently relies on the Elasticsearch `elastic` account, so restrict
network access and use that superuser only for initial validation; production
requires an approved identity/access design before broad access is granted.

### Dev-first rollout

1. In `k8s/dev/terraform/terraform.tfvars`, set `enable_efk = true`, retain the
   agreed dev sizing, and replace the Kibana hostname placeholder with a name
   under `ingress_domain_suffix` (by default
   `kibana.<ingress_domain_suffix>`). Confirm the selected ingress, DNS, and
   TLS inputs are correct. DNS records are not created by this Terraform
   configuration.
2. From the dev root, initialize the configured S3 backend, then run
   `terraform fmt -check`, `terraform validate`, and create a saved plan.
   Inspect that the plan is for the intended cluster and adds the ECK
   operator, Elasticsearch/Kibana resources, Fluent Bit, routing, and
   persistent volume claims. Review all changes before applying.
3. Apply only the reviewed saved plan. Then check readiness:

   ```sh
   kubectl -n logging get pods,pvc
   kubectl -n logging get elasticsearch,kibana
   ```

   Wait for Elasticsearch and Kibana to become healthy and Fluent Bit pods to
   be ready on the nodes. If pods are pending, inspect resource requests,
   StorageClass provisioning, and the Elasticsearch/Kibana operator events.
4. Retrieve the generated `elastic` password securely from the
   `elasticsearch-es-elastic-user` Secret in namespace `logging`; do not
   commit it, put it in tfvars, or paste it into tickets. Sign in at
   `https://<kibana_hostname>` and confirm expected indices and recent logs.
   Use the dev ingress only from networks authorized to reach its load
   balancer. To retrieve the password, run the following only in a trusted
   terminal and do not capture its output in logs or support tickets:

   ```sh
   kubectl -n logging get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 --decode
   ```

5. Check `kubectl -n logging get daemonsets,pods,secrets` for Fluent Bit
   readiness and the generated `efk-fluent-bit-api-key` Secret. Inspect
   Fluent Bit pod logs and Elasticsearch health/indices for successful
   ingestion. Remember log content can be sensitive. Confirm old test data is
   subject to the 14-day ILM policy.
6. Observe dev storage, CPU, memory, ingest rate, and retention through a
   representative period. Address capacity or access issues before proposing
   another environment.

### Enabling staging or production later

After dev validation, agree on the environment-specific hostname, DNS and
TLS, resource and storage budgets, log sensitivity, retention, access
controls, snapshots, restore tests, and an operational owner. Change only
that environment's `enable_efk` to `true`, use its documented capacity, and
follow the same saved-plan review and apply process. Staging is three
Elasticsearch nodes × 50Gi; production is three × 100Gi. Do not copy dev
state, credentials, API keys, or log data into another environment.

Do not disable EFK or destroy its namespace as a cleanup shortcut. First
decide whether the indexed logs must be retained or restored elsewhere, take
and verify a snapshot if required, and review the plan's workload and
persistent-volume effects. The local Helm chart installs a restricted
Fluent Bit API key and retention policy through a Kubernetes hook Job; check
the `logging` namespace events and Elasticsearch health if the install or
upgrade does not complete.

## Review the plan carefully

Do not apply if the plan targets the wrong AWS account, cluster, region, or
state key. Check environment tags and understand every resource replacement
and deletion. In particular:

- The AWS Load Balancer Controller and EKS Pod Identity Agent may be enabled
  automatically as dependencies of ingress, Argo CD, or Route 53 DNS-01.
- Disabling add-ons or changing `ingress_controller` can remove live
  resources. Review KEDA changes especially carefully because its CRDs can
  contain live `ScaledObject` resources.
- The cluster, VPC, worker nodes, and application Deployments are managed
  outside these platform roots.
- The current ingress options do **not** attach to a network-owned shared
  NLB. Envoy, NGINX, and F5 NGINX request their own NLB; ALB uses the AWS Load
  Balancer Controller. A shared-NLB design requires implementation and
  testing before changing these settings. See the [Kubernetes architecture
  guide](k8s/README.md).

## State and migration procedures

### Moving existing state to S3

The S3 backend examples use separate keys, encryption, and S3 lock files.
The approved bucket must already exist in the region configured in
`backend.hcl`. Enable bucket versioning and configure environment-scoped IAM
access to each environment's state object and lock file before initializing.
The dev, staging, and production backend examples use different keys
(`dev/terraform.tfstate`, `staging/terraform.tfstate`, and
`production/terraform.tfstate`) so their state stays isolated.

For dev's existing local state, back up `terraform.tfstate` securely before
changing backends. State can contain sensitive values; keep the backup
outside the repository in a protected location. Confirm the
`dev/terraform.tfstate` destination key is empty. From
`k8s/dev/terraform/`, run:

```sh
cp terraform.tfstate "$HOME/dev-terraform.tfstate.backup"
terraform init -migrate-state -backend-config=backend.hcl
```

Confirm the migration when prompted, then verify it with `terraform state
list`. Never migrate one environment's state into another environment's key.
For staging or production, if a local state is being migrated, follow the
same backup and empty-destination precautions using that environment's state
file and backend key. For a new root with no existing state, use
`terraform init -backend-config=backend.hcl` instead. Do not use
`-migrate-state` as a routine initialization option.

### One-time dev resource-address migration

The dev configuration moved several resources from root-level addresses into
`module.platform`. Only do this if `terraform state list` shows an old address
that still needs to be managed at the corresponding new address. Back up the
dev state securely first, skip absent old addresses and destinations already
in use, and run these commands from `k8s/dev/terraform/`:

```sh
terraform state mv 'aws_eks_addon.pod_identity_agent' 'module.platform.module.pod_identity_agent[0].aws_eks_addon.this'
terraform state mv 'aws_iam_policy.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_iam_policy.this'
terraform state mv 'aws_iam_role.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_iam_role.this'
terraform state mv 'aws_iam_role_policy_attachment.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_iam_role_policy_attachment.this'
terraform state mv 'aws_eks_pod_identity_association.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].aws_eks_pod_identity_association.this'
terraform state mv 'helm_release.aws_load_balancer_controller' 'module.platform.module.aws_load_balancer_controller[0].helm_release.this'
terraform state mv 'kubernetes_namespace.keda' 'module.platform.module.keda[0].kubernetes_namespace.this'
terraform state mv 'helm_release.keda' 'module.platform.module.keda[0].helm_release.this'
```

The destination module must be enabled in the dev configuration, and the
resource must remain owned by this root. Run `terraform plan` after the moves.
Do not apply if the plan unexpectedly replaces live add-ons or ingress
resources.

The optional `k8s/dev/terraform/ingress-dns01/` directory is a separate
standalone dev root with its own local state. Use it instead of the main dev
ingress path, not alongside it, if both would manage the same ingress,
cert-manager, or Pod Identity resources.

Terraform's `.terraform/` directory and `modules/modules.json` are generated
local initialization files. They are not Terraform state and should not be
edited or committed.

## ECR operations

ECR repositories and the image-publisher role are managed from `Ecr-Repo/`.
Supply an approved `cost_center`, initialize, validate, and review the plan
before applying. Images use immutable release tags; do not overwrite or retag
an existing image. The source workflow's publisher role is separate from
environment deployment roles.

Related operational docs:

- [ECR setup](Ecr-Repo/README.md)
- [Kubernetes architecture](k8s/README.md)
- [Dev environment](k8s/dev/README.md)
- [Staging environment](k8s/staging/README.md)
- [Production environment](k8s/production/README.md)
- [Source deployment runbook](https://github.com/qzee-dev/fintech-platform/blob/main/docs/DEPLOYMENT.md)
- [GitOps manifest runbook](https://github.com/qzee-dev/fintech-enterprise-gitops-manifest/blob/main/RUNBOOK.md)
