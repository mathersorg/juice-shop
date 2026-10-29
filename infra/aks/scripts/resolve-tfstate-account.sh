#!/usr/bin/env bash
# Print the terraform-state storage account to use.
# Prefer an account tagged tfstate_role=active, then a non-eastus account.
set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-brokenbank-demo}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID//[$'\t\r\n \"']/}"

az account set --subscription "$SUBSCRIPTION_ID" >/dev/null

python3 - "$RESOURCE_GROUP" <<'PY'
import json, subprocess, sys

rg = sys.argv[1]
raw = subprocess.check_output(
    [
        "az",
        "storage",
        "account",
        "list",
        "-g",
        rg,
        "-o",
        "json",
    ],
    text=True,
)
accounts = [
    a
    for a in json.loads(raw)
    if (a.get("tags") or {}).get("purpose") == "terraform-state"
]
if not accounts:
    sys.exit(0)

def rank(account: dict) -> tuple:
    tags = account.get("tags") or {}
    loc = (account.get("location") or "").lower().replace(" ", "")
    active = 0 if tags.get("tfstate_role") == "active" else 1
    # GitHub-hosted ubuntu runners are often eastus; IP rules do not apply there.
    same_region = 1 if loc == "eastus" else 0
    return (active, same_region, account["name"])

accounts.sort(key=rank)
print(accounts[0]["name"])
PY
