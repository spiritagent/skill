#!/bin/bash
# Usage: price.sh <token_address> <amount_in_wei> [direction] [user_address]
# direction: buy (ETH→token, default) or sell (token→ETH)
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

TOKEN="$1"
AMOUNT="$2"
DIRECTION="${3:-buy}"
USER_ADDRESS="${4:-${BASE_WALLET_ADDRESS}}"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured, cannot get price"
    exit 1
fi

if [ -z "$TOKEN" ] || [ -z "$AMOUNT" ]; then
    echo "Usage: $0 <token_address> <amount_in_wei> [direction] [user_address]"
    exit 1
fi

# Map direction to action
if [ "$DIRECTION" = "sell" ]; then
    ACTION="sell"
else
    ACTION="buy"
fi

# Build price request payload
PRICE_PAYLOAD=$(jq -n \
    --arg tokenAddress "$TOKEN" \
    --arg amount "$AMOUNT" \
    --arg action "$ACTION" \
    --arg userAddress "$USER_ADDRESS" \
    '{
        tokenAddress: $tokenAddress,
        amount: $amount,
        action: $action,
        userAddress: $userAddress
    }'
)

# Get price from platform
RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$PRICE_PAYLOAD" \
    "$PLATFORM_API_URL/api/v1/swap/price" 2>/dev/null || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "$RESPONSE_BODY" | jq '.data | {
        inputAmount: .inputAmount,
        outputAmount: .outputAmount,
        inputUSD: .inputAmountUSD,
        outputUSD: .outputAmountUSD,
        minOutput: .minOutputAmount,
        route: .route
    }'
else
    echo "❌ Price request failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
    exit 1
fi
