# Go-live checklist for Grafana and monitoring

This checklist is the final operational guide for bringing the fintech platform monitoring stack and the Fintech Platform Overview dashboard to a working state.

Use this after the platform repo is in place and the app services are instrumented. The repo already defines the architecture and observability contract in:

- [../README.md](../README.md)
- [RUNBOOK.md](../RUNBOOK.md)
- [OBSERVABILITY.md](OBSERVABILITY.md)
- [GRAFANA_DASHBOARD_RUNBOOK.md](GRAFANA_DASHBOARD_RUNBOOK.md)
- [FINTECH_PLATFORM_OVERVIEW_DASHBOARD.json](FINTECH_PLATFORM_OVERVIEW_DASHBOARD.json)

---

## 1. Prerequisites

Before going live, confirm the following:

- [ ] Terraform for the target environment has been applied successfully
- [ ] Prometheus is installed and healthy
- [ ] Grafana is reachable through the configured ingress hostname
- [ ] the OpenTelemetry Collector is healthy in the `monitoring` namespace
- [ ] the application services are deployed and running
- [ ] at least one representative request has been sent through the system
- [ ] the service metrics are visible in the Prometheus UI

---

## 2. Confirm platform health

Check the monitoring stack:

```sh
kubectl -n monitoring get pods,svc,pvc
kubectl -n monitoring get prometheus,prometheusrule
kubectl -n monitoring logs deploy/opentelemetry-collector --all-containers=true --since=15m
```

Verify:

- [ ] Prometheus pod is Running
- [ ] Grafana pod is Running
- [ ] Tempo pod is Running
- [ ] Collector pods are Running
- [ ] PVCs are Bound
- [ ] no crash loops or restart loops

---

## 3. Confirm Prometheus targets

Open Prometheus or use curl:

```bash
curl -s "http://<prometheus-host>:9090/api/v1/query?query=up" | jq
```

Expected result:

- [ ] `up` query returns metrics
- [ ] the OpenTelemetry Collector target is `UP`
- [ ] the expected app/service targets are present

If no targets are `UP`, stop and fix the scrape path before proceeding.

---

## 4. Validate live metrics

Run a representative query:

```bash
curl -s "http://<prometheus-host>:9090/api/v1/query?query=sum%20by%20(service_name)%20(rate(http_server_duration_count{service_namespace=%22fintech-platform%22}[5m]))" | jq
```

Expected result:

- [ ] a non-empty result set is returned
- [ ] service names are visible
- [ ] the data aligns with the services you expect to be active

If the query is empty:

- [ ] check the actual metric names emitted by the app
- [ ] verify the app is sending OTLP metrics
- [ ] confirm the service uses the expected environment labels

---

## 5. Import the Grafana dashboard

Follow the steps in [IMPORT_GRAFANA_DASHBOARD.md](IMPORT_GRAFANA_DASHBOARD.md).

Then import the JSON file:

- [FINTECH_PLATFORM_OVERVIEW_DASHBOARD.json](FINTECH_PLATFORM_OVERVIEW_DASHBOARD.json)

Verify:

- [ ] dashboard loads without errors
- [ ] the datasource is correctly selected
- [ ] panels render data or show the expected empty state

---

## 6. Validate the dashboard panels

Check panel by panel:

- [ ] Service request rate shows traffic
- [ ] Service error rate shows failures when present
- [ ] p95 latency by service shows values
- [ ] Transaction success/failure has data
- [ ] Payment failure count shows values
- [ ] Fraud alerts update when relevant traffic occurs
- [ ] Notification delivery status is populated
- [ ] DLQ retry count changes when retries occur
- [ ] Redis/Kafka dependency health panel is usable if exposed
- [ ] Web page/API latency shows values

If a panel is empty, investigate the metric or config before considering the dashboard ready.

---

## 7. Validate trace and log paths

The repo also expects traces and logs to flow separately from metrics.

### Traces

- [ ] Tempo is reachable from Grafana
- [ ] a sample service trace is visible in Tempo
- [ ] service metadata is attached

### Logs

- [ ] JSON app logs are written to stdout/stderr
- [ ] Fluent Bit is shipping log records
- [ ] Elasticsearch/Kibana is receiving the logs
- [ ] trace_id and span_id are present when applicable

---

## 8. Business validation

Send representative traffic through the application and confirm the dashboard reflects it.

Examples:

- [ ] user login or register traffic
- [ ] wallet creation or balance query
- [ ] transaction attempt
- [ ] payment attempt
- [ ] fraud evaluation trigger
- [ ] notification send attempt
- [ ] web page request through the frontend

Expected result:

- [ ] the service-specific dashboards respond to real traffic
- [ ] no panel is permanently empty when it should have data

---

## 9. Operational readiness

Before calling the stack ready, confirm the following:

- [ ] all required services are reporting to Prometheus
- [ ] Grafana dashboard imports successfully
- [ ] no broken or missing panel queries remain
- [ ] the environment is using the right datasource and labels
- [ ] team members know where the dashboard and docs live
- [ ] alerting is configured and tested if required

---

## 10. Final sign-off

The dashboard is production-ready only when all of the following are true:

- [ ] Prometheus is healthy
- [ ] Grafana is healthy
- [ ] Collector is healthy
- [ ] app metrics are visible and consistent
- [ ] dashboard loads and contains valid data
- [ ] the business flows are reflected in the metrics
- [ ] logs and traces are independently validated

Once all boxes are checked, the dashboard is ready for regular operational use.
