# Grafana dashboard approaches for the fintech platform

This repository provisions the monitoring platform for the application services in the fintech platform repo. The application code emits telemetry through OpenTelemetry, Prometheus scrapes the metrics, and Grafana visualizes them.

This document compares the two practical ways to build Grafana dashboards for this stack and recommends the best default approach.

## 1. Architecture reminder

The intended flow is:

- application services emit OTLP metrics and traces
- Prometheus scrapes those metrics
- Grafana queries Prometheus for dashboard panels
- traces and logs are handled separately in Tempo and Elasticsearch/Kibana

The repo contract is described in:

- [../README.md](../README.md)
- [OBSERVABILITY.md](OBSERVABILITY.md)
- [../../fintech-platform/docs/OBSERVABILITY.md](../../fintech-platform/docs/OBSERVABILITY.md)

The exact metric names depend on the instrumentation library and the semantic conventions used by each service. The dashboard should rely on the real Prometheus series emitted after deployment.

---

## 2. Approach A: Manual Grafana dashboard creation

This is the simplest approach when you are validating the telemetry or creating the first dashboard quickly.

### Best use cases

- initial validation of Prometheus targets
- proving the application metrics are arriving
- building a quick proof-of-concept dashboard
- small environments with a limited number of panels

### Typical workflow

1. Confirm the target is being scraped:

```promql
up
```

2. Check that a metric exists for a specific service:

```promql
sum by (service_name) (rate(http_server_duration_count{service_namespace="fintech-platform"}[5m]))
```

3. Build a panel for request rate.

```promql
sum by (service_name) (rate(http_server_duration_count{service_namespace="fintech-platform"}[5m]))
```

4. Build an error panel.

```promql
sum by (service_name) (rate(http_server_duration_count{service_namespace="fintech-platform", http_status_code=~"5.."}[5m]))
```

5. Build a latency panel.

```promql
histogram_quantile(
  0.95,
  sum by (service_name, le) (
    rate(http_server_duration_bucket{service_namespace="fintech-platform"}[5m])
  )
)
```

### Strengths

- very fast to start
- good for learning the real metric names
- easy to adjust while validating dashboard behavior

### Weaknesses

- time-consuming for many services
- easy to drift from the common naming standard
- not repeatable across environments
- harder to maintain over time

### Recommendation

Use this approach only as a fast first pass or for local validation. It is not the best long-term operational pattern for a microservices platform like this one.

---

## 3. Approach B: Dashboard-as-code / automated Grafana provisioning

This is the preferred and more scalable approach for this project.

### Best use cases

- multiple services and environments
- consistent dashboards across dev, staging, and production
- repeatable deployment with GitOps
- minimal manual errors
- easier team onboarding

### How to do it

1. Standardize metric labels and names across services.
2. Define shared Prometheus recording rules.
3. Create Grafana dashboards as JSON files stored in the repo.
4. Provision them through Grafana provisioning or Kubernetes ConfigMaps.

### Standard labels to require

Every service should emit metadata that allows consistent filtering and grouping:

- service_name
- service_namespace
- deployment_environment_name
- service_instance_id
- status_code or outcome

Example resource attributes are already defined in the app repo:

- service.name
- service.namespace
- deployment.environment.name
- service.instance.id

### Example recording rules

These provide stable, reusable queries for dashboards:

```promql
service_http_requests_total:rate5m = sum by (service_name, service_namespace, deployment_environment_name) (
  rate(http_server_duration_count[5m])
)

service_http_errors_total:rate5m = sum by (service_name, service_namespace, deployment_environment_name) (
  rate(http_server_duration_count{http_status_code=~"5.."}[5m])
)

service_http_latency_p95 = histogram_quantile(
  0.95,
  sum by (service_name, le) (
    rate(http_server_duration_bucket[5m])
  )
)
```

These recording rules make dashboards simpler and keep the panel logic consistent.

### Recommended dashboard structure

Use a small number of dashboards, not one dashboard per service:

#### Dashboard 1: Platform Health

Panels:

- `up` for all scrape targets
- request rate by service
- error rate by service
- p95 latency by service
- JVM/Node runtime utilization (if exposed)

#### Dashboard 2: Transaction Flow

Panels:

- transaction attempts per second
- transaction success vs failure
- payment attempts and failures
- fraud alert rate
- notification delivery success/failure

#### Dashboard 3: Integration and Recovery

Panels:

- DLQ retry count
- queue lag or backlog if exported
- downstream dependency latency
- mock bank validation latency

#### Dashboard 4: Web / UX

Panels:

- frontend page load time
- API latency from browser or gateway
- UI error rate

### Strengths

- consistent across environments
- reusable and maintainable
- easier to review in Git
- supports GitOps and promotion workflows

### Weaknesses

- requires a standard naming and panel design process
- needs validation before production rollout
- slightly more setup effort initially

### Recommendation

This is the best path for a production-quality fintech observability setup.

---

## 4. Recommended PromQL patterns

These are the core queries you will reuse across dashboards.

### Request rate by service

```promql
sum by (service_name) (
  rate(http_server_duration_count{service_namespace="fintech-platform"}[5m])
)
```

### Error rate by service

```promql
sum by (service_name) (
  rate(http_server_duration_count{service_namespace="fintech-platform", http_status_code=~"5.."}[5m])
)
```

### p95 latency by service

```promql
histogram_quantile(
  0.95,
  sum by (service_name, le) (
    rate(http_server_duration_bucket{service_namespace="fintech-platform"}[5m])
  )
)
```

### Transaction success/failure split

```promql
sum by (service_name, result) (
  rate(transaction_attempts_total{service_namespace="fintech-platform"}[5m])
)
```

### Payment failures

```promql
sum by (service_name) (
  rate(payment_failures_total{service_namespace="fintech-platform"}[5m])
)
```

### Fraud alerts

```promql
sum by (service_name) (
  rate(fraud_alerts_total{service_namespace="fintech-platform"}[5m])
)
```

### DLQ retry rate

```promql
sum by (service_name) (
  rate(dlq_retries_total{service_namespace="fintech-platform"}[5m])
)
```

### Service health check

```promql
up{service_name=~"api-gateway|user-service|wallet-service|transaction-service|payment-service|fraud-service|notification-service|ledger-service|dlq-processor"}
```

---

## 5. Service-by-service dashboard focus

The application repo describes the telemetry contract for the services. In Grafana, the dashboard should reflect the expected operational data types for each service:

| Service | Primary Grafana signal | Typical metric type |
| --- | --- | --- |
| api-gateway | request rate, status code count, p95 latency | counter + histogram |
| user-service | auth attempts and failures | counter |
| wallet-service | wallet operations, balance events, failures | counter |
| transaction-service | attempts, success/failure, retries | counter |
| payment-service | payment attempts, validation failures | counter |
| fraud-service | fraud checks and alerts | counter |
| notification-service | delivered vs failed sends | counter |
| ledger-service | postings and reconciliation failures | counter |
| dlq-processor | retry count and backlog recovery | counter |
| nibss-mock | validation request rate, latency | counter + histogram |
| web | page load time, API latency | histogram |

This is the minimum useful service-focused monitoring coverage.

---

## 6. Recommended default for this repo

For this project, the best default recommendation is:

- start with a manual dashboard only to validate real metric names
- then migrate to a dashboard-as-code approach for all environment dashboards
- keep dashboards minimal and service-grouped rather than highly granular
- standardize labels and metric conventions across all services before expanding dashboard coverage

This gives you the best balance of speed, reliability, and maintainability.

---

## 7. Summary

### Manual dashboard

Good for:

- validation
- quick testing
- small experiments

Not ideal for:

- production scalability
- multi-service consistency
- long-term maintainability

### Automated dashboard-as-code

Good for:

- repeatability
- production operations
- team standardization
- GitOps-friendly deployment

Best choice for:

- the fintech platform repo and its Kubernetes monitoring environment

---

## 8. Final recommendation

Use the automated approach as the long-term standard, and use the manual approach only as a short validation step. For this repo, the right operational answer is: build a concise Grafana overview dashboard from Prometheus metrics, then automate it with dashboard provisioning and recording rules.
