#!/usr/bin/env bash
# Allow a public IPv4 or CIDR on a Premium ACR firewall (ARM).
# Usage: allow-acr-ip.sh <acr_name> [ipv4|/cidr]
set -euo pipefail

ACR="${1:-}"
IP="${2:-}"
SLEEP_SECONDS="${ACR_FIREWALL_SLEEP_SECONDS:-20}"

if [[ -z "$ACR" ]]; then
  echo "usage: $0 <acr_name> [ipv4|/cidr]" >&2
  exit 1
fi

if [[ -z "$IP" ]]; then
  IP="$(curl -4 -fsS --max-time 10 https://api.ipify.org | tr -d '[:space:]')"
fi

if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  :
elif [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
  :
else
  echo "error: not an IPv4 or CIDR: ${IP}" >&2
  exit 1
fi

existing="$(az acr network-rule list --name "$ACR" \
  --query "ipRules[?ipAddressOrRange=='${IP}' || ipAddressOrRange=='${IP}/32'].ipAddressOrRange" \
  -o tsv 2>/dev/null || true)"

if [[ -n "$existing" ]]; then
  echo "[acr] ${ACR} already allows ${IP}"
  sleep 10
  exit 0
fi

echo "[acr] Allowing ${IP} on ${ACR} ..."
az acr network-rule add --name "$ACR" --ip-address "$IP" --output none
echo "[acr] Waiting ${SLEEP_SECONDS}s for firewall propagation..."
sleep "$SLEEP_SECONDS"
