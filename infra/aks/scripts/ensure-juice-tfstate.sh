#!/usr/bin/env bash
# Allow this runner to use the lab tfstate account and write infra/aks/backend.hcl.
# State key is juice-shop/terraform.tfstate. This does not copy or retag the VM state.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-brokenbank-demo}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID//[$'\t\r\n \"']/}"
BACKEND_HCL="${BACKEND_HCL:-${ROOT}/infra/aks/backend.hcl}"
STATE_KEY="juice-shop/terraform.tfstate"

chmod +x "${ROOT}/infra/aks/scripts/resolve-tfstate-account.sh" "${ROOT}/infra/aks/scripts/allow-storage-ip.sh"
az account set --subscription "$SUBSCRIPTION_ID"
SA="$(${ROOT}/infra/aks/scripts/resolve-tfstate-account.sh)"
if [[ -z "$SA" || "$SA" == "null" ]]; then
  echo "error: no storage account tagged purpose=terraform-state in ${RESOURCE_GROUP}" >&2
  exit 1
fi

"${ROOT}/infra/aks/scripts/allow-storage-ip.sh" "$SA"
KEY="$(az storage account keys list -g "$RESOURCE_GROUP" -n "$SA" --query "[0].value" -o tsv)"

if ! az storage blob list \
  --account-name "$SA" \
  --account-key "$KEY" \
  --container-name tfstate \
  --num-results 1 \
  -o tsv >/dev/null 2>&1; then
  echo "error: runner cannot list blobs in ${SA}/tfstate. Same-region runners ignore storage IP rules." >&2
  exit 1
fi

mkdir -p "$(dirname "$BACKEND_HCL")"
printf '%s\n' \
  'resource_group_name  = "rg-brokenbank-demo"' \
  "storage_account_name = \"${SA}\"" \
  'container_name       = "tfstate"' \
  "key                  = \"${STATE_KEY}\"" \
  > "$BACKEND_HCL"
echo "[storage] ${SA}/tfstate key ${STATE_KEY}"
echo "storage_account=${SA}" >> "${GITHUB_OUTPUT:-/dev/null}"
