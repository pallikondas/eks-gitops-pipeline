# MegaMart ShopCore

ShopCore is a Node.js/Express microservices platform deployed to Amazon EKS with Terraform, Helm, Argo CD, ALB Ingress, DynamoDB, HPA, Cluster Autoscaler, Prometheus, and Grafana.

Use [REQUIREMENTS_TRACEABILITY.md](REQUIREMENTS_TRACEABILITY.md) as the release gate against the capstone requirements.

## Repository layout

```text
app/
  order-service/
  catalog-service/
infrastructure/terraform/
helm/
  order-service/
  catalog-service/
gitops/
  apps/
  environments/
  platform/
  observability/
```

## Bootstrap AWS infrastructure

Use an authenticated AWS identity in `us-east-1` and verify the target account before applying:

```sh
aws sts get-caller-identity
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

For the default local-state capstone workflow, run `terraform init -backend=false` instead of `terraform init`. Use the S3 backend initialization described in [infrastructure/README.md](infrastructure/README.md) when the GitHub destroy workflow will manage the same state.

The baseline creates the three-AZ VPC, EKS 1.36 cluster, private managed node group, ECR repositories, DynamoDB orders table, OIDC provider, and IRSA roles. Review the plan and expected AWS cost before applying.

## Install platform prerequisites

Configure kubectl and install the AWS Load Balancer Controller chart using the IRSA ServiceAccount in `gitops/platform/aws-load-balancer-controller-serviceaccount.yaml` and the role output described in [infrastructure/README.md](infrastructure/README.md). Install Argo CD once in the cluster, then register the GitOps Applications in `gitops/apps`. The Metrics Server Application provides the resource metrics API required by HPA.

For the GitHub deployment workflow, create a protected `GRAFANA_ADMIN_PASSWORD` secret in the `deploy-dev` environment. The workflow creates the `monitoring` namespace and Kubernetes secret without printing the password. For manual bootstrap, create the Grafana admin secret through the approved secret-management process:

```sh
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic grafana-admin-credentials \
  --namespace monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='REPLACE_WITH_SECRET_MANAGER_VALUE'
```

Do not commit the password. Production environments should source this secret from AWS Secrets Manager through the organization’s secret synchronization controller.

## Trigger GitOps synchronization

Argo CD owns application and platform resources after bootstrap. Do not deploy application resources with manual `kubectl apply`.

```sh
kubectl apply -f gitops/apps/order-service.yaml
kubectl apply -f gitops/apps/catalog-service.yaml
kubectl apply -f gitops/apps/order-service-prod.yaml
kubectl apply -f gitops/apps/catalog-service-prod.yaml
kubectl apply -f gitops/apps/cluster-autoscaler.yaml
kubectl apply -f gitops/apps/observability-stack.yaml
kubectl apply -f gitops/apps/observability-dashboards.yaml
argocd app list
argocd app sync order-service-dev
argocd app sync catalog-service-dev
```

The `kubectl apply` commands above are bootstrap registration only. Subsequent workload changes must be committed to Git and synchronized by Argo CD.

## Validate the services

The services are `ClusterIP` and are exposed through one internet-facing ALB. The ALB controller routes `/orders` and `/products` using the shared `shopcore` Ingress group.

```sh
kubectl get ingress -A
kubectl get pods -n order-service-dev
kubectl get pods -n catalog-service-dev
kubectl get hpa -A
kubectl get servicemonitor -A
```

After DNS points `shopcore.example.com` at the ALB, validate:

```sh
curl https://shopcore.example.com/orders/health
curl 'https://shopcore.example.com/products?search=headphones'
curl https://shopcore.example.com/products/p-laptop-001/inventory
```

To test failover, delete one service pod and confirm the ALB remains healthy while Kubernetes replaces the pod:

```sh
kubectl delete pod -n order-service-dev -l app.kubernetes.io/name=order-service --wait=false
kubectl get pods -n order-service-dev -w
```

## Test autoscaling

Generate traffic against the ALB or a port-forwarded service, then watch HPA state:

```sh
kubectl run load-generator --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c 'while true; do wget -q -O- http://order-service.order-service-dev/orders/health; done'
kubectl get hpa -n order-service-dev -w
kubectl delete pod load-generator
```

Cluster Autoscaler should discover the managed node group through its ASG tags. To exercise it, deploy a temporary workload with requests that exceed available capacity, observe pending pods and node scale-out, then remove the workload and confirm scale-in after the configured delay.

## Destroy after testing

Destroy the environment immediately after testing to stop AWS charges and remove exposed resources. The guarded script verifies the AWS account, restricts the target to the `megamart-shopcore-dev` environment, removes Argo CD Applications first, and then runs Terraform destruction.

Local-state teardown:

```sh
./scripts/destroy-environment.sh DESTROY-megamart-shopcore-dev
# At the prompt, type: megamart-shopcore-dev
```

For a GitHub-hosted teardown, configure the `destroy-dev` environment approval and these secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `TF_BACKEND_BUCKET`, `TF_BACKEND_KEY`, and `TF_BACKEND_REGION`. Manually run `Destroy ShopCore Environment` with the exact input `DESTROY-megamart-shopcore-dev`.

The ECR repositories use `force_delete` because this is an ephemeral capstone environment. Do not copy that setting into a retained production registry. Never run the destroy workflow against a production state key.

## Deploy with failure cleanup

For a complete environment deployment, manually run the `Deploy ShopCore Environment` workflow. Enter `DEPLOY-megamart-shopcore-dev`, enable `destroy_on_failure`, and approve the `deploy-dev` environment. The workflow runs in order: Terraform plan/apply, Argo CD and platform bootstrap, then platform verification. It intentionally does not wait for application pods or an ALB before the service images exist.

After the deployment workflow succeeds, run both service workflows from `main`: `CI/CD Pipeline - Order Service` and `CI/CD Pipeline - Catalog Service`. Each workflow runs tests, CodeQL, an image scan, pushes an immutable SHA tag to ECR, and promotes that tag to the dev GitOps values file. Argo CD then rolls out the services. Only after both workflows succeed should you run the application, ALB, HPA, autoscaler, and load-test checks below.

If any deployment stage fails, the workflow pauses at the protected `destroy-dev` environment and, after approval, removes Argo Applications before running Terraform destroy. This cleanup requires the same S3 backend secrets as the standalone destroy workflow. Keep `destroy_on_failure` enabled for disposable capstone runs; disable it only when intentionally preserving a partially deployed environment for investigation.

## Observability

Prometheus scrapes `/metrics` from both services through `ServiceMonitor` resources. Grafana loads the ShopCore dashboard from `gitops/observability/grafana-shopcore-dashboard.yaml`.

```sh
kubectl port-forward -n monitoring svc/observability-grafana 3000:80
kubectl port-forward -n monitoring svc/observability-kube-prometheus-prometheus 9090:9090
```

The dashboard covers request rate, p95 latency, ready pods, and HPA replica counts. Cluster metrics come from kube-state-metrics and node-exporter.# eks-gitops-pipeline