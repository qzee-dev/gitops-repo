# Import the Fintech Platform Overview dashboard

This guide explains how to import the ready-made Grafana dashboard JSON into your Grafana instance.

## Files

- [FINTECH_PLATFORM_OVERVIEW_DASHBOARD.json](FINTECH_PLATFORM_OVERVIEW_DASHBOARD.json)

## Import steps

1. Open Grafana.
2. Go to Dashboard > New > Import.
3. Click Upload JSON file.
4. Select the JSON file from this folder.
5. Choose the Prometheus datasource.
6. Save the dashboard.

## If the datasource name is different

The dashboard JSON is configured with the Prometheus datasource UID `prometheus`. If your Grafana deployment uses a different datasource UID or name, update it in Grafana before saving.

## Common validation checks

After importing, verify that the dashboard is populated:

- `up` targets are healthy
- Prometheus target is reachable
- service metrics are returning series
- transaction and payment panels show values
- errors / latency queries produce data

## If a panel is empty

The most common reasons are:

- the service has not emitted the metric yet
- the label names differ from the expected names
- the telemetry is not deployed yet
- Prometheus is not scraping the target

Follow the runbook in [GRAFANA_DASHBOARD_RUNBOOK.md](GRAFANA_DASHBOARD_RUNBOOK.md) for troubleshooting and metric validation.
