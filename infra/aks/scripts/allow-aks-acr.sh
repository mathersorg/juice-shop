#!/usr/bin/env bash
# Let the juice-shop node subnet pull from the Deny-firewalled registry.
# AcrPull on the kubelet is not enough when the node path is blocked.
set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-brokenbank-demo}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID//[$'\t\r\n \"']/}"
CLUSTER="${AKS_CLUSTER_NAME:-juice-shop}"
ACR="${1:-badbankrehzuh}"

az account set --subscription "$SUBSCRIPTION_ID"

NODE_RG="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER" --query nodeResourceGroup -o tsv)"
KUBELET_ID="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER" --query identityProfile.kubeletidentity.objectId -o tsv)"
ACR_ID="$(az acr show -n "$ACR" -g "$RESOURCE_GROUP" --query id -o tsv)"
echo "[acr] kubelet ${KUBELET_ID}"
echo "[acr] node resource group ${NODE_RG}"

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

SUBNET_ID="$(az network vnet list -g "$NODE_RG" --query "[0].subnets[0].id" -o tsv)"
VNET_NAME="$(az network vnet list -g "$NODE_RG" --query "[0].name" -o tsv)"
SUBNET_NAME="$(az network vnet list -g "$NODE_RG" --query "[0].subnets[0].name" -o tsv)"
echo "[acr] node subnet ${SUBNET_ID}"

az network vnet subnet update \
  --resource-group "$NODE_RG" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --service-endpoints Microsoft.ContainerRegistry \
  --output none

if az acr network-rule list --name "$ACR" -g "$RESOURCE_GROUP" \
  --query "virtualNetworkRules[?contains(virtualNetworkResourceId, '${SUBNET_NAME}')].virtualNetworkResourceId" -o tsv \
  | grep -q .; then
  echo "[acr] ${ACR} already allows the node subnet"
else
  echo "[acr] Allowing node subnet on ${ACR}"
  az acr network-rule add --name "$ACR" -g "$RESOURCE_GROUP" --subnet "$SUBNET_ID" --output none
fi

echo "[acr] Waiting 30s for the subnet rule"
sleep 30
az aks check-acr -g "$RESOURCE_GROUP" -n "$CLUSTER" --acr "$ACR"
