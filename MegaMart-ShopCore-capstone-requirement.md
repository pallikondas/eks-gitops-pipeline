# MegaMart ShopCore Capstone Requirements

## 1. Executive Summary & Scenario

You are consulting for **MegaMart**, a rapidly growing online retail enterprise. Its core platform is a legacy monolithic web application called **ShopCore**.

Currently, ShopCore runs on a traditional architecture that buckles under traffic spikes during flash sales, suffers from slow deployment pipelines, and lacks automated fault recovery.

MegaMart is moving to a **cloud-native, GitOps-driven architecture on Amazon EKS**.

Your mission is to modernize ShopCore by:
- Breaking it apart into microservices.
- Containerizing it.
- Deploying it via GitOps.
- Architecting it for enterprise-grade security.
- Providing high availability and resiliency.
- Improving cost efficiency.

---

## 2. Architecture & Technical Requirements

The final solution must address the **five pillars of the AWS Well-Architected Framework**, incorporating the following specific constraints and mechanisms.

### 2.1 Monolith Decomposition

Break ShopCore into at least two distinct microservices:

#### Catalog-Service
Handles:
- Product listings.
- Search queries.
- Inventory lookups.

#### Order-Service
Handles:
- Customer checkouts.
- Cart items.
- Interaction with persistent storage.

### 2.2 Containerization

Package both services into optimized **multi-stage Docker images**.

Store the resulting container images in **Amazon ECR**.

### 2.3 GitOps Deployment

Manage all Kubernetes:
- Manifests.
- Helm charts.
- Configurations.

These must be managed through a **Git repository** using a GitOps controller such as **Argo CD or Flux**.

> **Production constraint:** No manual `kubectl apply` in production.

### 2.4 Resiliency & High Availability

- Deploy the EKS data plane across **multiple Availability Zones (AZs)**.
- Implement **Horizontal Pod Autoscaling (HPA)** based on custom or resource metrics such as CPU and memory.
- Configure **Cluster Autoscaler** — **do not use Karpenter** — to dynamically scale worker nodes based on pod scheduling demands.

### 2.5 Security & IAM

Use **IAM Roles for Service Accounts (IRSA)** so that the Order-Service can securely read/write to:
- An Amazon DynamoDB table, or
- An Amazon S3 bucket for order logs/receipts.

AWS credentials must **not** be hardcoded into the application or Kubernetes manifests.

### 2.6 Observability

Set up:
- **Prometheus** for metrics collection.
- **Grafana** for dashboards.

The monitoring solution must scrape cluster metrics and provide real-time dashboards covering:
- Application health.
- Request latency.
- Autoscaling events.

### 2.7 Traffic Management & Testing

Expose the services using an **AWS Load Balancer Controller** through:
- ALB Ingress, or
- NLB.

Validate:
- External access.
- Traffic routing.
- Failover behavior.

### 2.8 Right-Sizing & Cost

Define precise Kubernetes resource:
- Requests.
- Limits.

Select appropriate EC2 instance types for worker nodes to prevent over-provisioning.

---

## 3. Deliverables

The team must deliver a **single GitHub repository** structured logically for:
- Application code.
- Infrastructure.
- GitOps synchronization.

The repository must include the following.

### 3.1 Application Code

Source code for the decomposed microservices:
- Catalog-Service.
- Order-Service.

Each service must include its respective Dockerfile.

### 3.2 Infrastructure as Code

Terraform or CloudFormation scripts used to provision the baseline infrastructure, including:
- VPC.
- EKS cluster.
- DynamoDB and/or S3 resources.
- IAM OIDC provider for IRSA.

> Terraform is optional/recommended according to the original requirement.

### 3.3 Kubernetes & GitOps Manifests

Include:
- Deployments.
- Services.
- Ingress resources.
- HPA configurations.
- IAM trust policies.
- Kubernetes `ServiceAccount` annotations for IRSA.
- Helm charts or raw manifests structured for the selected GitOps tool.

### 3.4 Monitoring Configurations

Include:
- Prometheus `ServiceMonitor` resources.
- Grafana dashboard JSON models.

### 3.5 Runbook (`README.md`)

Provide step-by-step instructions covering:
1. How to bootstrap the environment.
2. How to trigger GitOps synchronization.
3. How to simulate flash-sale load.
4. How to test the HPA.
5. How to test the Cluster Autoscaler.
6. How to view application and infrastructure metrics in Grafana.
7. How to validate external access and failover.

---

## 4. Reference

- AWS EKS Best Practices: https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html

