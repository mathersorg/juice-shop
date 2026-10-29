#!/usr/bin/env bash
# Allow this runner to use a reachable lab tfstate account and write infra/aks/backend.hcl.
# State key is juice-shop/terraform.tfstate. This does not copy VM state or retag the lab account.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-brokenbank-demo}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID//[$'\t\r\n \"']/}"
BACKEND_HCL="${BACKEND_HCL:-${ROOT}/infra/aks/backend.hcl}"
STATE_KEY="juice-shop/terraform.tfstate"
ALLOW="${ROOT}/infra/aks/scripts/allow-storage-ip.sh"

chmod +x "$ALLOW"
az account set --subscription "$SUBSCRIPTION_ID"

# The first Terraform run allowed this runner on the eastus state account, then
# failed before it could remove the rule. Same-region runners ignore that rule.
az storage account network-rule remove \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --account-name badbanktf18gsg2 \
  --ip-address 130.131.255.218 \
  --output none 2>/dev/null || true

RUNNER_IP="$(curl -4 -fsS --max-time 10 https://api.ipify.org | tr -d '[:space:]')"

probe() {
  local sa="$1"
  local key
  key="$(az storage account keys list -g "$RESOURCE_GROUP" -n "$sa" --query "[0].value" -o tsv)"
  az storage blob list \
    --account-name "$sa" \
    --account-key "$key" \
    --container-name tfstate \
    --num-results 1 \
    -o tsv >/dev/null 2>&1
}

drop_ip() {
  local sa="$1"
  az storage account network-rule remove \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$sa" \
    --ip-address "$RUNNER_IP" \
    --output none 2>/dev/null || true
}

write_backend() {
  local sa="$1"
  mkdir -p "$(dirname "$BACKEND_HCL")"
  printf '%s\n' \
    'resource_group_name  = "rg-brokenbank-demo"' \
    "storage_account_name = \"${sa}\"" \
    'container_name       = "tfstate"' \
    "key                  = \"${STATE_KEY}\"" \
    > "$BACKEND_HCL"
  echo "[storage] ${sa}/tfstate key ${STATE_KEY}"
}

try_account() {
  local sa="$1"
  echo "[storage] trying ${sa}"
  "$ALLOW" "$sa" "$RUNNER_IP" || return 1
  if probe "$sa"; then
    write_backend "$sa"
    return 0
  fi
  echo "[storage] ${sa} is not reachable from this runner"
  drop_ip "$sa"
  return 1
}

mapfile -t accounts < <(az storage account list -g "$RESOURCE_GROUP" \
  --query "[?tags.purpose=='terraform-state'].[name,location,tags.tfstate_role]" -o tsv \
  | awk -F'\t' '{
      role=$3; loc=tolower($2); name=$1
      rank=2
      if (role=="juice-shop") rank=0
      else if (loc!="eastus") rank=1
      print rank "\t" name
    }' | sort | awk -F'\t' '{print $2}')

for sa in "${accounts[@]}"; do
  [[ -z "$sa" ]] && continue
  if try_account "$sa"; then
    exit 0
  fi
done

name="badbankjs$(python3 -c 'import secrets,string; print("".join(secrets.choice(string.ascii_lowercase + string.digits) for _ in range(6)))')"
echo "[storage] Creating ${name} in westus2 for juice-shop state"
az storage account create \
  --name "$name" \
  --resource-group "$RESOURCE_GROUP" \
  --location westus2 \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --https-only true \
  --allow-blob-public-access false \
  --public-network-access Enabled \
  --default-action Deny \
  --bypass AzureServices \
  --tags purpose=terraform-state tfstate_role=juice-shop project=juice-shop application=juice-shop \
  --output none
"$ALLOW" "$name" "$RUNNER_IP"
key="$(az storage account keys list -g "$RESOURCE_GROUP" -n "$name" --query "[0].value" -o tsv)"
az storage container create --name tfstate --account-name "$name" --account-key "$key" --public-access off --output none
if ! probe "$name"; then
  echo "error: created ${name} but this runner still cannot list blobs" >&2
  exit 1
fi
write_backend "$name"
