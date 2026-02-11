#!/bin/bash
# Fetch agent's recent onchain transactions
set -euo pipefail
source "$(dirname "$0")/../.env" 2>/dev/null || true

LIMIT="${1:-10}"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" || -z "${BASE_WALLET_ADDRESS:-}" ]]; then
    echo "No transactions."
    exit 0
fi

curl -s -H "Authorization: Bearer $PLATFORM_API_KEY" \
    "$PLATFORM_API_URL/api/v1/wallet/transactions?address=$BASE_WALLET_ADDRESS&limit=$LIMIT" 2>/dev/null | \
    jq -r '.data.transactions // [] | if length == 0 then "No recent transactions." else .[] | "\(.timestamp) | \(.type) | \(.amount) \(.token_symbol) | \(if .type == "sent" then "→ " + .to[:10] + "..." else "← " + .from[:10] + "..." end) | \(.hash[:14])..." end' 2>/dev/null || echo "No transactions."
