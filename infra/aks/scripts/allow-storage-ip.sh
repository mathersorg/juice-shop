#!/usr/bin/env bash
# Allow a public IPv4 address on a storage account firewall (ARM; works when data plane is denied).
# Usage: allow-storage-ip.sh <storage_account_name> [ipv4]
set -euo pipefail

SA="${1:-}"
IP="${2:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-brokenbank-demo}"
# Trim quotes/newlines; a quoted GitHub secret makes az fail.
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID//[$'\t\r\n \"']/}"
OLD_SUBSCRIPTION_ID="e0f7ff17-d0a3-4cde-ac0c-f4177a42b6a0"
SLEEP_SECONDS="${STORAGE_FIREWALL_SLEEP_SECONDS:-15}"

if [[ -z "$SA" ]]; then
  echo "usage: $0 <storage_account_name> [ipv4]" >&2
  exit 1
fi

if [[ "$SUBSCRIPTION_ID" == "$OLD_SUBSCRIPTION_ID" ]]; then
  echo "error: AZURE_SUBSCRIPTION_ID is the deleted Product Demo subscription ${OLD_SUBSCRIPTION_ID}." >&2
  echo "error: Set GitHub secret AZURE_SUBSCRIPTION_ID to 2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300." >&2
  exit 1
fi

if [[ -z "$IP" ]]; then
  IP="$(curl -4 -fsS --max-time 10 https://api.ipify.org | tr -d '[:space:]')"
fi

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: not an IPv4 address: ${IP}" >&2
  exit 1
fi

if ! az account set --subscription "$SUBSCRIPTION_ID"; then
  echo "error: cannot select subscription ${SUBSCRIPTION_ID}." >&2
  echo "error: Check GitHub secrets AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID." >&2
  az account show --query "{id:id, name:name, tenantId:tenantId}" -o json >&2 || true
  exit 1
fi
echo "[storage] Using Azure CLI subscription ${SUBSCRIPTION_ID}"

existing="$(az storage account network-rule list \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$SA" \
  --query "ipRules[?ipAddressOrRange=='${IP}'].ipAddressOrRange" -o tsv)"

if [[ -n "$existing" ]]; then
  echo "[storage] ${SA} already allows ${IP}"
  exit 0
fi

echo "[storage] Allowing ${IP} on ${SA} ..."
az storage account network-rule add \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$SA" \
  --ip-address "$IP" \
  --output none

echo "[storage] Waiting ${SLEEP_SECONDS}s for firewall propagation..."
sleep "$SLEEP_SECONDS"
