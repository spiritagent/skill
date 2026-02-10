#!/bin/bash
# Usage: swap.sh <buy|sell> <token_address> <amount_in_wei>
# Executes swap via platform (quote + execute in one call)
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ACTION="$1"
TOKEN="$2"
AMOUNT="$3"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured, cannot swap"
    exit 1
fi

if [ -z "$ACTION" ] || [ -z "$TOKEN" ] || [ -z "$AMOUNT" ]; then
    echo "Usage: $0 <buy|sell> <token_address> <amount_in_wei>"
    exit 1
fi

echo "💱 Executing swap via platform..." >&2

PAYLOAD=$(jq -n \
    --arg tokenAddress "$TOKEN" \
    --arg amount "$AMOUNT" \
    --arg action "$ACTION" \
    '{tokenAddress: $tokenAddress, amount: $amount, action: $action}')

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$PAYLOAD" \
    "$PLATFORM_API_URL/api/v1/swap/execute" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ Swap executed!" >&2
    echo "$BODY" | jq '.data | {
        hash: .hash,
        inputAmount: .inputAmount,
        outputAmount: .outputAmount,
        inputUSD: .inputAmountUSD,
        outputUSD: .outputAmountUSD
    }'
else
    echo "❌ Swap failed (HTTP $HTTP_CODE)" >&2
    echo "$BODY" >&2
    exit 1
fi
