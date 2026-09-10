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
      kubectl delete application \
        order-service-dev catalog-service-dev cluster-autoscaler metrics-server \
        aws-load-balancer-controller-serviceaccount observability-stack observability-dashboards \
        --namespace argocd --ignore-not-found --wait=true --timeout=10m
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
terraform destroy -input=false -auto-approve
printf 'Destroy completed for %s in %s.\n' "${CLUSTER_NAME}" "${AWS_REGION}"