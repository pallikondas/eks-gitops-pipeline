# Grafana Evidence

Grafana was port-forwarded locally from the monitoring Service and the authenticated `MegaMart ShopCore` dashboard was opened.

Verified populated panels:

- Request Rate with `orders` and `catalog` series
- Request Latency p95 with order and catalog series
- HPA Current Replicas
- Application Health

Prometheus was Ready, its `up` query included both application services, and the dashboard panels were bound to the provisioned datasource UID `prometheus`.

## Screenshot artifact

The dashboard screenshot was captured during the live validation session in the VS Code browser. Before external submission, export/save that screenshot as:

```text
grafana-shopcore-dashboard.png
```

in this folder if the submission requires a binary image file. Do not include Grafana credentials or session data.
