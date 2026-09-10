# MegaMart infrastructure

This directory provisions the baseline AWS platform for ShopCore. Application images, Kubernetes manifests, GitOps synchronization, and observability are intentionally handled in later phases.

## Provisioned baseline

- A three-AZ VPC with public and private subnets and NAT gateway access.
- An Amazon EKS cluster with a managed node group spread across private subnets.
- ECR repositories for Catalog Service and Order Service with immutable tags and scan-on-push.
- A pay-per-request DynamoDB table for orders with point-in-time recovery.
- EKS OIDC/IRSA roles for Order Service DynamoDB access and Cluster Autoscaler.
- An IRSA role for the AWS Load Balancer Controller, which creates ALBs from Kubernetes Ingress resources.

## Verify and apply

From `infrastructure/terraform`:

```sh
cp terraform.tfvars.example terraform.tfvars
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

For the GitHub Actions destroy workflow, use an S3 backend bucket created outside this Terraform state. Initialize with:

```sh
terraform init \
	-backend-config="bucket=$TF_BACKEND_BUCKET" \
	-backend-config="key=megamart-shopcore/dev/terraform.tfstate" \
	-backend-config="region=$AWS_REGION"
```

The bucket must already exist and should have versioning and encryption enabled. The workflow requires `TF_BACKEND_BUCKET`, `TF_BACKEND_KEY`, and `TF_BACKEND_REGION` secrets. Local teardown uses local state when these variables are unset.

Before applying, confirm the selected AWS account and region:

```sh
aws sts get-caller-identity
aws configure get region
```

After applying, verify the control plane and worker nodes:

```sh
aws eks update-kubeconfig --region "$(terraform output -raw aws_region)" --name "$(terraform output -raw cluster_name)"
kubectl get nodes -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

After applying, create the controller service account using the Terraform output and install the current AWS Load Balancer Controller chart:

```sh
kubectl create serviceaccount aws-load-balancer-controller --namespace kube-system
kubectl annotate serviceaccount aws-load-balancer-controller \
	--namespace kube-system \
	eks.amazonaws.com/role-arn="$(terraform output -raw aws_load_balancer_controller_role_arn)"

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
	--namespace kube-system \
	--set clusterName="$(terraform output -raw cluster_name)" \
	--set region="$(terraform output -raw aws_region)" \
	--set vpcId="$(terraform output -raw vpc_id)" \
	--set serviceAccount.create=false \
	--set serviceAccount.name=aws-load-balancer-controller
```

The Kubernetes service account must be annotated with the Terraform role ARN and use the `kube-system` namespace before this Helm command. If the service account already exists, use `kubectl annotate ... --overwrite`.

Do not run `terraform apply` until the plan has been reviewed for the target AWS account. The single NAT gateway is a cost-conscious development default; production should use one NAT gateway per AZ or an equivalent egress design.