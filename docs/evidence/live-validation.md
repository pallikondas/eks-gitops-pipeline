# Live Validation

## Platform

- Region: `us-east-1`
- EKS cluster: `megamart-shopcore-dev`
- Worker nodes: Ready across `us-east-1a`, `us-east-1b`, and `us-east-1c`
- ALB: `k8s-shopcore-0aaeecc407-1453337050.us-east-1.elb.amazonaws.com`
- ALB scheme/state: internet-facing / active

## External routes

All requests used `Host: shopcore.example.com` and returned HTTP 200:

- `/orders/health`
- `/products?search=headphones`
- `/products/p-laptop-001/inventory`

Order health response:

```json
{"status":"healthy","version":"dev"}
```

## DynamoDB and IRSA

A POST to `/orders` created order `d1db221d-2cee-4fb9-bec0-c6408fda7c0f`; a subsequent GET returned the same order. The Order Service pod used the annotated IRSA role and no static AWS credentials.

## HPA and load test

A bounded internal load test ran for approximately 60 seconds:

| Service | Successful requests | Failures |
|---|---:|---:|
| Order Service | 18,435 | 0 |
| Catalog Service | 17,429 | 0 |

Both HPAs reacted from 2 to 6 replicas with CPU and memory metrics available.

## Pod failover

One Order Service pod was deleted. Kubernetes created a ready replacement, the ready count recovered, and the ALB `/orders/health` endpoint remained HTTP 200.
