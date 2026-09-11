# MegaMart ShopCore Requirements Traceability

**Review date:** 2026-09-11
**Branch:** `megamart-shopcore`  
**Target AWS account:** `517811334008`  
**Target region:** `us-east-1`  
**Release decision:** Ready for capstone sign-off; live application, platform, resilience, observability, and cleanup evidence is complete.

## Status legend

- **Implemented:** Present in the repository and locally validated.
- **Implemented, AWS verification pending:** Configuration is present, but requires a live EKS/AWS validation.
- **Partial:** Some implementation exists, but one or more requirement details remain incomplete.
- **Gap:** Required implementation is missing.

## Traceability matrix

| ID | Requirement | Evidence | Status | Validation / release action |
|---|---|---|---|---|
| 2.1 | At least two microservices: Catalog Service and Order Service | `app/catalog-service/`; `app/order-service/` | Implemented | Unit tests pass for both services. |
| 2.1a | Catalog product listings | `app/catalog-service/src/index.js` `GET /products` | Implemented | Tested by `app/catalog-service/tests/unit/catalog.test.js`. |
| 2.1b | Catalog search queries | `app/catalog-service/src/index.js` `GET /products?search=...` | Implemented | Search unit test passes. |
| 2.1c | Catalog inventory lookups | `app/catalog-service/src/index.js` `GET /products/:productId/inventory` | Implemented | Inventory unit test passes. |
| 2.1d | Order checkout and cart items | `app/order-service/src/index.js` `POST /orders` | Implemented | Supports single item and `cartItems`; unit tests pass. |
| 2.1e | Order persistent storage | `app/order-service/src/index.js`; `ORDER_TABLE_NAME`; DynamoDB Terraform resource | Implemented, live-tested | ALB POST `/orders` created order `d1db221d-2cee-4fb9-bec0-c6408fda7c0f`; subsequent GET returned the same order through IRSA-backed DynamoDB access. |
| 2.2 | Multi-stage Docker image for each service | `app/catalog-service/Dockerfile`; `app/order-service/Dockerfile` | Implemented | Both production targets build successfully. |
| 2.2a | Secure, current image base | Both Dockerfiles use digest-pinned Node 24 Alpine and `apk upgrade` | Implemented | Docker Scout reported `0 critical / 0 high` on both final images. Re-scan on every base-image refresh. |
| 2.2b | Images stored in ECR | `infrastructure/terraform/main.tf` ECR repositories; `.github/workflows/ci-cd.yaml`; `.github/workflows/catalog-service-ci-cd.yaml` | Implemented, live-tested | Both service workflows completed successfully with immutable SHA-tagged images deployed to EKS. |
| 2.3 | Kubernetes and Helm configuration managed in Git | `helm/`; `gitops/` | Implemented | Helm dev/prod templates render successfully. |
| 2.3a | GitOps controller | `gitops/apps/*.yaml` Argo CD Applications, including dev/prod application manifests | Implemented, live-tested | Dev service Applications and observability Applications reported `Synced` and `Healthy`; image promotions were reconciled from `main`. |
| 2.3b | No manual production workload apply | Argo CD automated sync policies; `README.md` bootstrap distinction | Implemented for capstone | Manual apply is limited to initial Argo registration/platform bootstrap; application changes are promoted through Git and reconciled by Argo CD. |
| 2.4 | EKS data plane across multiple AZs | `infrastructure/terraform/main.tf`; `variables.tf` requires 3 AZs; managed node group uses private subnets | Implemented, live-tested | Three Ready nodes were observed across `us-east-1a`, `us-east-1b`, and `us-east-1c`. |
| 2.4a | HPA using resource metrics | `helm/order-service/templates/hpa.yaml`; `helm/catalog-service/templates/hpa.yaml`; `gitops/apps/metrics-server.yaml` | Implemented, live-tested | CPU and memory metrics were available; the simple load test scaled both services from 2 to 6 replicas. |
| 2.4b | Cluster Autoscaler, not Karpenter | `gitops/platform/cluster-autoscaler.yaml`; `gitops/apps/cluster-autoscaler.yaml`; Terraform ASG tags and IAM | Implemented, live-tested | Bounded pressure test scaled the node group from 3 to 6 nodes, then back to the configured minimum of 3 after workload cleanup. |
| 2.5 | IRSA/OIDC enabled | `module.eks.enable_irsa = true`; `module.eks.oidc_provider_arn` trust policies | Implemented, live-tested | EKS OIDC-backed web identity variables were present in the Order Service pod and DynamoDB access succeeded. |
| 2.5a | Order Service DynamoDB least-privilege access | `aws_iam_role.order_service`; `aws_iam_role_policy.order_service_dynamodb` | Implemented, live-tested | The Order Service created and read an order through the ALB; pod environment showed the IRSA web identity variables and no static AWS keys. |
| 2.5b | Kubernetes ServiceAccount annotation | `helm/order-service/templates/serviceaccount.yaml`; dev/prod values | Implemented, live-tested | The Order Service pod used the annotated IRSA role and had no static AWS credentials. |
| 2.5c | No hardcoded AWS credentials | Application and manifests use IRSA role ARN/table configuration only | Implemented | Run secret scanning before push and inspect pod environment/configuration after deployment. |
| 2.6 | Prometheus metrics collection | `gitops/apps/observability-stack.yaml`; ServiceMonitors; `/metrics` endpoints | Implemented, live-tested | Prometheus was Ready and its `up` query included both `order-service` and `catalog-service` targets. |
| 2.6a | Grafana dashboards | `gitops/observability/grafana-shopcore-dashboard.yaml` | Implemented, live-tested | Authenticated Grafana dashboard screenshot captured with populated ShopCore panels. |
| 2.6b | Application health, latency, autoscaling metrics | Node metrics middleware; dashboard panels for request rate, p95 latency, ready pods, HPA replicas | Implemented, live-tested | Grafana displayed request rate, p95 latency, HPA replica, and application health panels; Prometheus targets included both services. |
| 2.7 | AWS Load Balancer Controller | Terraform IAM policy/role; `gitops/platform/aws-load-balancer-controller-serviceaccount.yaml`; `infrastructure/README.md` Helm install | Implemented, live-tested | Controller pods were Ready after the Terraform IAM policy fix. |
| 2.7a | ALB Ingress exposure | `helm/*/templates/ingress.yaml`; `ClusterIP` Services; shared `shopcore` ALB group; deployment workflow waits for the ALB controller | Implemented, live-tested | Internet-facing ALB `k8s-shopcore-0aaeecc407-1453337050.us-east-1.elb.amazonaws.com` was Active and served both routes with HTTP 200. |
| 2.7b | External access, routing, failover | `README.md` Host-header-aware ALB curl checks, pod deletion, and ALB validation procedures | Implemented, live-tested | ALB routes returned HTTP 200; deleting one Order Service pod produced a ready replacement while `/orders/health` remained healthy. |
| 2.8 | Kubernetes resource requests and limits | `helm/*/values.yaml`; environment overrides; platform manifests | Implemented | Helm output contains requests and limits for application and platform workloads. |
| 2.8a | Right-sized worker instances | `variables.tf` defaults to `t3.medium`; managed node group config | Implemented, live-tested | `t3.medium` workers supported the bounded load and autoscaler tests across three AZs; single NAT remains an explicit dev cost default. |
| 3.1 | Application source and Dockerfiles | `app/catalog-service/`; `app/order-service/` | Implemented | Both services have source, tests, lockfiles, and Dockerfiles. |
| 3.2 | Infrastructure as Code | `infrastructure/terraform/` | Implemented | `terraform fmt`, `terraform validate`, and AWS `terraform plan` pass. |
| 3.3 | Deployments, Services, Ingress, HPA, trust, ServiceAccounts | `helm/`; `gitops/platform/`; `infrastructure/terraform/main.tf` | Implemented, live-tested | Helm rendered the required resources and the live cluster served both services through Argo-managed Deployments, Services, Ingresses, HPAs, ServiceMonitors, and IRSA. |
| 3.4 | Prometheus ServiceMonitors and Grafana JSON | `helm/*/templates/servicemonitor.yaml`; `gitops/observability/grafana-shopcore-dashboard.yaml` | Implemented, live-tested | ServiceMonitors exist, Prometheus `up` includes both applications, and the authenticated Grafana dashboard displayed populated panels. |
| 3.5 | Required runbook | `README.md`; `infrastructure/README.md` | Implemented | Covers bootstrap, GitOps, load, HPA, Cluster Autoscaler, Grafana, access, and failover. Execute it after bootstrap and record results. |
| 3.5a | Destroy after testing to control cost and exposure | `scripts/destroy-environment.sh`; `.github/workflows/destroy-environment.yaml`; `infrastructure/terraform/backend.tf` | Implemented | Local teardown supports local state; GitHub teardown requires S3 backend secrets and protected `destroy-dev` approval. Run after each test session and verify the target resources are gone. |
| 3.5b | Roll back/destroy incomplete deployment | `.github/workflows/deploy-environment.yaml`; `.github/workflows/destroy-environment.yaml` | Implemented | Deployment workflow runs sequentially through platform verification, leaves application rollout to the two image workflows, and invokes approval-gated cleanup on platform failure when `destroy_on_failure` is enabled. |

## Pre-deployment gate

The repository may proceed to controlled AWS bootstrap only after these checks remain green:

```sh
aws sts get-caller-identity
terraform -chdir=infrastructure/terraform fmt -check -recursive
terraform -chdir=infrastructure/terraform validate
terraform -chdir=infrastructure/terraform plan -out=megamart.tfplan
helm template order-service helm/order-service -f gitops/environments/dev/values-dev.yaml
helm template catalog-service helm/catalog-service -f gitops/environments/dev/catalog-values-dev.yaml
```

Review the plan before applying. The current plan creates the VPC, EKS 1.36 cluster, managed nodes, ECR repositories, DynamoDB table, and IAM resources. Do not apply if the account, region, instance sizing, or estimated cost is not intended.

## Post-bootstrap verification gate

After the infrastructure exists, the following evidence is still mandatory before calling the capstone complete:

1. EKS nodes are Ready across multiple AZs.
2. AWS Load Balancer Controller is healthy and an ALB has been provisioned.
3. Both service routes return healthy responses through the ALB.
4. Order Service successfully writes and reads an order from DynamoDB through IRSA.
5. Both HPAs report resource metrics and react to load.
6. Cluster Autoscaler scales the managed node group out and back in.
7. Prometheus reports healthy ServiceMonitor targets.
8. Grafana displays request rate, p95 latency, application health, and HPA data.
9. Pod deletion and node/pod pressure tests demonstrate recovery.
10. ECR images are immutable, scan clean at the required severity threshold, and are referenced by deployed GitOps values.

## Sign-off checklist

- [x] Both microservices, unit tests, Dockerfiles, Helm charts, ECR workflows, and immutable image promotion.
- [x] Terraform infrastructure, EKS cluster, three Ready nodes across three AZs, OIDC/IRSA, and least-privilege DynamoDB access.
- [x] Argo CD synchronization, AWS Load Balancer Controller, Active shared ALB, external routing, and HTTP 200 API evidence.
- [x] HPA metrics and bounded load test: Order 18,435 successful requests, Catalog 17,429, zero recorded failures; both scaled from 2 to 6 replicas.
- [x] Prometheus, Alertmanager, Grafana, ServiceMonitors, and application targets verified after server-side CRD bootstrap correction.
- [x] Cluster Autoscaler scale-out and scale-in evidence.
- [x] Pod deletion/failover evidence.
- [x] Grafana dashboard panel evidence.
- [x] Repository deliverables and sign-off documentation are cleanly captured; user-local GitOps values edits were preserved and the final implementation changes were merged through PR #19.

The implementation is **ready for capstone sign-off**. The live evidence covers Cluster Autoscaler behavior, pod failover, and Grafana dashboard panels in addition to the application, ALB, IRSA, HPA, load, and Prometheus checks.
