#!/usr/bin/env bash
# Confirm the kubelet can pull. The private endpoint, DNS, and VNet peering
# are created by Terraform in infra/aks. This does not open the public firewall
# to the node subnet.
set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-brokenbank-demo}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID//[$'\t\r\n \"']/}"
CLUSTER="${AKS_CLUSTER_NAME:-juice-shop}"
ACR="${1:-badbankrehzuh}"

az account set --subscription "$SUBSCRIPTION_ID"

KUBELET_ID="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER" --query identityProfile.kubeletidentity.objectId -o tsv)"
ACR_ID="$(az acr show -n "$ACR" -g "$RESOURCE_GROUP" --query id -o tsv)"
echo "[acr] kubelet ${KUBELET_ID}"

existing="$(az role assignment list --scope "$ACR_ID" --assignee-object-id "$KUBELET_ID" --role AcrPull --query "[0].id" -o tsv)"
if [[ -z "$existing" ]]; then
  echo "[acr] Granting AcrPull on ${ACR} to the kubelet"
  az role assignment create \
    --role AcrPull \
    --scope "$ACR_ID" \
    --assignee-object-id "$KUBELET_ID" \
    --assignee-principal-type ServicePrincipal \
    --output none
else
  echo "[acr] kubelet already has AcrPull"
fi

az aks check-acr -g "$RESOURCE_GROUP" -n "$CLUSTER" --acr "$ACR"
