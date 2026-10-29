#!/usr/bin/env bash
# Restore ACR default-action Deny after a CI job.
# Usage: relock-acr-firewall.sh [acr_name]
set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-brokenbank-demo}"
FLAG="${ACR_FIREWALL_OPENED_FLAG:-${RUNNER_TEMP:-/tmp}/acr-firewall-opened}"

registries=()
if [[ -n "${1:-}" ]]; then
  registries+=("$1")
fi
if [[ -f "$FLAG" ]]; then
  while read -r line; do
    [[ -n "$line" ]] && registries+=("$line")
  done < "$FLAG"
fi
if [[ ${#registries[@]} -eq 0 ]]; then
  echo "[acr] no registry to relock"
  exit 0
fi

uniq_regs="$(printf '%s\n' "${registries[@]}" | awk 'NF && !seen[$0]++')"
while read -r ACR; do
  echo "[acr] Setting ${ACR} default-action Deny"
  az acr update --name "$ACR" --resource-group "$RESOURCE_GROUP" --default-action Deny --output none
  echo "[acr] ${ACR} firewall restored to Deny"
done <<< "$uniq_regs"
