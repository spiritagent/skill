#!/bin/bash
# Usage: swap.sh <buy|sell> <token_address> <amount_in_wei> [user_address]
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ACTION="$1"
TOKEN="$2"
AMOUNT="$3"
USER_ADDRESS="${4:-${BASE_WALLET_ADDRESS}}"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured, cannot swap"
    exit 1
fi

if [ -z "$ACTION" ] || [ -z "$TOKEN" ] || [ -z "$AMOUNT" ]; then
    echo "Usage: $0 <buy|sell> <token_address> <amount_in_wei> [user_address]"
    exit 1
fi

echo "💱 Getting swap quote via platform..."

# Step 1: Get swap quote with calldata
QUOTE_PAYLOAD=$(jq -n \
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

QUOTE_RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$QUOTE_PAYLOAD" \
    "$PLATFORM_API_URL/api/v1/swap/quote" 2>/dev/null || echo "000")

QUOTE_HTTP_CODE="${QUOTE_RESPONSE: -3}"
QUOTE_BODY="${QUOTE_RESPONSE%???}"

if [[ "$QUOTE_HTTP_CODE" != "200" ]]; then
    echo "❌ Quote failed (HTTP $QUOTE_HTTP_CODE)"
    echo "$QUOTE_BODY"
    exit 1
fi

QUOTE_DATA=$(echo "$QUOTE_BODY" | jq '.data')
echo "$QUOTE_DATA" | jq '{inputUSD: .inputAmountUSD, outputUSD: .outputAmountUSD, route: .route}'

# Extract transaction data
TO=$(echo "$QUOTE_DATA" | jq -r '.to')
VALUE=$(echo "$QUOTE_DATA" | jq -r '.value // "0"')
CALLDATA=$(echo "$QUOTE_DATA" | jq -r '.data')

if [ -z "$CALLDATA" ] || [ "$CALLDATA" = "null" ]; then
    echo "ERROR: No transaction data returned from quote"
    exit 1
fi

# Step 2: Execute swap via platform tx endpoint
echo "🔄 Executing swap via server wallet..."
TX_PAYLOAD=$(jq -n \
    --arg to "$TO" \
    --arg value "$VALUE" \
    --arg data "$CALLDATA" \
    '{
        to: $to,
        value: $value,
        data: $data
    }'
)

TX_RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$TX_PAYLOAD" \
    "$PLATFORM_API_URL/api/v1/tx/send" 2>/dev/null || echo "000")

TX_HTTP_CODE="${TX_RESPONSE: -3}"
TX_BODY="${TX_RESPONSE%???}"

if [[ "$TX_HTTP_CODE" == "200" || "$TX_HTTP_CODE" == "201" ]]; then
    echo "✅ Swap transaction sent successfully"
    echo "$TX_BODY" | jq '{hash: .data.hash}'
else
    echo "❌ Swap transaction failed (HTTP $TX_HTTP_CODE)"
    echo "$TX_BODY"
    exit 1
fi

echo "🎉 Swap complete!"
