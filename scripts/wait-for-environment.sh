#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-megamart-shopcore}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
POLL_SECONDS="${POLL_SECONDS:-10}"
STARTED_AT="$(date +%s)"

require_command() {
  command -v "$1" >/dev/null || { printf '%s is required\n' "$1" >&2; exit 1; }
}

require_command kubectl

kubectl cluster-info >/dev/null

get_app_status() {
  local app_name="$1"
  local field="$2"
  kubectl get application "${app_name}" -n argocd -o "jsonpath={.status.${field}}" 2>/dev/null || true
}

get_ingress_hostname() {
  local namespace="$1"
  local ingress_name="$2"
  kubectl get ingress "${ingress_name}" -n "${namespace}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
}

get_endpoint_count() {
  local namespace="$1"
  local service_name="$2"
  kubectl get endpoints "${service_name}" -n "${namespace}" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | awk '{print NF}'
}

print_status() {
  local order_sync order_health catalog_sync catalog_health order_alb catalog_alb
  order_sync="$(get_app_status order-service-dev sync.status)"
  order_health="$(get_app_status order-service-dev health.status)"
  catalog_sync="$(get_app_status catalog-service-dev sync.status)"
  catalog_health="$(get_app_status catalog-service-dev health.status)"
  order_alb="$(get_ingress_hostname order-service-dev order-service)"
  catalog_alb="$(get_ingress_hostname catalog-service-dev catalog-service)"
  printf '[%s] order=%s/%s catalog=%s/%s ALB(order=%s catalog=%s) endpoints(order=%s catalog=%s)\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
    "${order_sync:-Pending}" "${order_health:-Pending}" \
    "${catalog_sync:-Pending}" "${catalog_health:-Pending}" \
    "${order_alb:-Pending}" "${catalog_alb:-Pending}" \
    "$(get_endpoint_count order-service-dev order-service-stable)" \
    "$(get_endpoint_count catalog-service-dev catalog-service)"
}

while true; do
  order_sync="$(get_app_status order-service-dev sync.status)"
  order_health="$(get_app_status order-service-dev health.status)"
  catalog_sync="$(get_app_status catalog-service-dev sync.status)"
  catalog_health="$(get_app_status catalog-service-dev health.status)"
  order_alb="$(get_ingress_hostname order-service-dev order-service)"
  catalog_alb="$(get_ingress_hostname catalog-service-dev catalog-service)"
  order_endpoints="$(get_endpoint_count order-service-dev order-service-stable)"
  catalog_endpoints="$(get_endpoint_count catalog-service-dev catalog-service)"

  print_status

  if [[ "${order_sync}" == "Synced" && "${order_health}" == "Healthy" \
    && "${catalog_sync}" == "Synced" && "${catalog_health}" == "Healthy" \
    && -n "${order_alb}" && "${order_alb}" == "${catalog_alb}" \
    && "${order_endpoints}" -gt 0 && "${catalog_endpoints}" -gt 0 ]]; then
    printf '\nEnvironment is ready.\n'
    printf 'ALB_HOST=%s\n' "${order_alb}"
    printf 'curl -i -H '\''Host: shopcore.example.com'\'' "http://%s/orders/health"\n' "${order_alb}"
    printf 'curl -i -H '\''Host: shopcore.example.com'\'' "http://%s/products?search=headphones"\n' "${order_alb}"
    exit 0
  fi

  elapsed_seconds=$(( $(date +%s) - STARTED_AT ))
  if (( elapsed_seconds >= TIMEOUT_SECONDS )); then
    printf '\nTimed out after %ss. Final state:\n' "${TIMEOUT_SECONDS}" >&2
    print_status >&2
    exit 1
  fi
  sleep "${POLL_SECONDS}"
done
