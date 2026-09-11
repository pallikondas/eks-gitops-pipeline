#!/usr/bin/env bash
set -euo pipefail

EXPECTED_PROJECT="megamart-shopcore"
EXPECTED_ENVIRONMENT="dev"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${REPO_ROOT}/infrastructure/terraform"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-${EXPECTED_PROJECT}}"
ENVIRONMENT="${ENVIRONMENT:-${EXPECTED_ENVIRONMENT}}"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

if [[ "${PROJECT_NAME}" != "${EXPECTED_PROJECT}" || "${ENVIRONMENT}" != "${EXPECTED_ENVIRONMENT}" ]]; then
  printf 'Refusing to destroy unexpected target: project=%s environment=%s\n' "${PROJECT_NAME}" "${ENVIRONMENT}" >&2
  exit 1
fi

if [[ "${1:-}" != "DESTROY-${PROJECT_NAME}-${ENVIRONMENT}" ]]; then
  printf 'Usage: %s DESTROY-%s-%s\n' "$0" "${PROJECT_NAME}" "${ENVIRONMENT}" >&2
  exit 2
fi

command -v aws >/dev/null || { printf 'aws CLI is required\n' >&2; exit 1; }
command -v terraform >/dev/null || { printf 'terraform is required\n' >&2; exit 1; }

printf 'Destruction target: AWS account and cluster %s in %s\n' "${CLUSTER_NAME}" "${AWS_REGION}"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
read -r -p 'Type the exact target name to continue: ' confirmation
if [[ "${confirmation}" != "${CLUSTER_NAME}" ]]; then
  printf 'Confirmation did not match. Nothing was destroyed.\n' >&2
  exit 1
fi

if aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  if command -v kubectl >/dev/null; then
    aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null

    if kubectl cluster-info >/dev/null 2>&1; then
      printf 'Removing GitOps Applications so ALB and workload resources are cleaned up first...\n'
      for app in \
        order-service-dev catalog-service-dev cluster-autoscaler metrics-server \
        aws-load-balancer-controller-serviceaccount observability-stack observability-dashboards; do
        kubectl delete application "${app}" --namespace argocd --ignore-not-found --wait=false || true
      done
    else
      printf 'kubectl cannot reach the cluster; Terraform will continue with infrastructure destruction.\n' >&2
    fi
  else
    printf 'kubectl is unavailable; Terraform will continue with infrastructure destruction.\n' >&2
  fi
fi

cd "${TERRAFORM_DIR}"
if [[ -n "${TF_BACKEND_BUCKET:-}" ]]; then
  : "${TF_BACKEND_KEY:?TF_BACKEND_KEY is required when TF_BACKEND_BUCKET is set}"
  : "${TF_BACKEND_REGION:?TF_BACKEND_REGION is required when TF_BACKEND_BUCKET is set}"
  terraform init -input=false \
    -backend-config="bucket=${TF_BACKEND_BUCKET}" \
    -backend-config="key=${TF_BACKEND_KEY}" \
    -backend-config="region=${TF_BACKEND_REGION}"
else
  terraform init -input=false -backend=false
fi

# The ALB controller can create security groups outside Terraform. Once the
# cluster and load balancer are gone, remove only orphaned groups in this
# dedicated project VPC before Terraform attempts to delete the VPC.
vpc_id="$(aws ec2 describe-vpcs \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Project,Values=${PROJECT_NAME}" "Name=tag:Environment,Values=${ENVIRONMENT}" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)"
if [[ -n "${vpc_id}" && "${vpc_id}" != "None" ]]; then
  eni_count="$(aws ec2 describe-network-interfaces \
    --region "${AWS_REGION}" --filters "Name=vpc-id,Values=${vpc_id}" \
    --query 'length(NetworkInterfaces)' --output text 2>/dev/null || printf '0')"
  if [[ "${eni_count}" == "0" ]]; then
    for security_group_id in $(aws ec2 describe-security-groups \
      --region "${AWS_REGION}" --filters "Name=vpc-id,Values=${vpc_id}" \
      --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
      aws ec2 delete-security-group --region "${AWS_REGION}" --group-id "${security_group_id}" || true
    done
  else
    printf 'Retaining VPC security groups while %s network interfaces remain.\n' "${eni_count}" >&2
  fi
fi

destroy_succeeded=false
for attempt in 1 2 3; do
  if terraform destroy -input=false -auto-approve; then
    destroy_succeeded=true
    break
  fi
  printf 'Terraform destroy attempt %s failed; retrying for asynchronous AWS cleanup.\n' "${attempt}" >&2
done
if [[ "${destroy_succeeded}" != true ]]; then
  printf 'Terraform destroy failed after 3 attempts.\n' >&2
  exit 1
fi
printf 'Destroy completed for %s in %s.\n' "${CLUSTER_NAME}" "${AWS_REGION}"