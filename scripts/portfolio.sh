#!/bin/bash
# Usage: portfolio.sh [address]
# Outputs portfolio data as JSON (via platform API)
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ADDRESS="${1:-$BASE_WALLET_ADDRESS}"

if [ -z "$ADDRESS" ]; then
    echo "Error: No wallet address specified" >&2
    exit 1
fi

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "Error: Platform not configured" >&2
    exit 1
fi

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    "$PLATFORM_API_URL/api/v1/wallet/balance?address=$ADDRESS" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "$BODY" | jq '.data'
else
    echo "Error: Balance fetch failed (HTTP $HTTP_CODE)" >&2
    echo '{"address":"'$ADDRESS'","total_usd":"0","eth_balance":"0","eth_usd":"0","tokens":[]}'
fi
