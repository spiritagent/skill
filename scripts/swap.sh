#!/bin/bash
# Usage: swap.sh <buy|sell> <token_address> <amount_in_wei> [slippage_pct]
# slippage_pct: default 1 (= 1%). Set higher for volatile memecoins.
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ACTION="$1"
TOKEN="$2"
AMOUNT="$3"
SLIPPAGE="${4:-1}"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured, cannot swap"
    exit 1
fi

if [ -z "$ACTION" ] || [ -z "$TOKEN" ] || [ -z "$AMOUNT" ]; then
    echo "Usage: $0 <buy|sell> <token_address> <amount_in_wei> [slippage_pct]"
    echo "  slippage_pct: default 1 (1%). Use 5-10 for memecoins."
    exit 1
fi

echo "💱 Executing swap via platform (slippage: ${SLIPPAGE}%)..." >&2

PAYLOAD=$(jq -n \
    --arg tokenAddress "$TOKEN" \
    --arg amount "$AMOUNT" \
    --arg action "$ACTION" \
    --argjson slippage "$SLIPPAGE" \
    '{tokenAddress: $tokenAddress, amount: $amount, action: $action, slippage: $slippage}')

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
    
    RESULT=$(echo "$BODY" | jq '.data | {
        hash: .hash,
        inputToken: .inputToken,
        outputToken: .outputToken,
        inputAmount: .inputAmount,
        outputAmount: .outputAmount,
        minOutputAmount: .minOutputAmount,
        inputUSD: .inputAmountUSD,
        outputUSD: .outputAmountUSD,
        slippage: .slippage
    }')
    echo "$RESULT"

    # Auto-report trade to platform
    TX_HASH=$(echo "$BODY" | jq -r '.data.hash // empty')
    if [[ -n "$TX_HASH" ]]; then
        TRADE_REPORT=$(echo "$BODY" | jq '{
            tx_hash: .data.hash,
            chain_id: 8453,
            token_in: .data.inputToken,
            token_out: .data.outputToken,
            token_in_symbol: (.data.inputTokenSymbol // ""),
            token_out_symbol: (.data.outputTokenSymbol // ""),
            amount_in: .data.inputAmount,
            amount_out: .data.outputAmount,
            price_usd: (.data.outputAmountUSD // "0"),
            dex: (.data.dex // "gluex"),
            executed_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }')
        
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $PLATFORM_API_KEY" \
            -d "$TRADE_REPORT" \
            "$PLATFORM_API_URL/api/v1/trades" >/dev/null 2>&1 &
        echo "📊 Trade reported to platform" >&2
    fi
else
    echo "❌ Swap failed (HTTP $HTTP_CODE)" >&2
    echo "$BODY" >&2
    exit 1
fi
