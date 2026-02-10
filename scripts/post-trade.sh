#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

TRADE_DATA="$1"

if [[ -z "$TRADE_DATA" ]]; then
    echo "Usage: $0 '<trade_json>'"
    exit 1
fi

# Parse trade data
ACTION=$(echo "$TRADE_DATA" | jq -r '.action')
SYMBOL=$(echo "$TRADE_DATA" | jq -r '.symbol')
AMOUNT_IN_USD=$(echo "$TRADE_DATA" | jq -r '.amountInUSD')
AMOUNT_OUT_USD=$(echo "$TRADE_DATA" | jq -r '.amountOutUSD')
TX_HASH=$(echo "$TRADE_DATA" | jq -r '.txHash')

case "$ACTION" in
    "buy")  EMOJI="🚀"; ACTION_TEXT="Bought" ;;
    "sell") EMOJI="💰"; ACTION_TEXT="Sold" ;;
    *)      EMOJI="📈"; ACTION_TEXT="Traded" ;;
esac

TWEET_TEXT="$EMOJI $ACTION_TEXT \$$SYMBOL

💵 Value: \$${AMOUNT_IN_USD} → \$${AMOUNT_OUT_USD}
🔗 TX: https://basescan.org/tx/${TX_HASH}

#Base #DeFi #Crypto #Trading"

# Truncate if too long
if [[ ${#TWEET_TEXT} -gt 280 ]]; then
    TWEET_TEXT="$EMOJI $ACTION_TEXT \$$SYMBOL - \$${AMOUNT_IN_USD} → \$${AMOUNT_OUT_USD}

🔗 https://basescan.org/tx/${TX_HASH}

#Base #DeFi"
fi

echo "🐦 Posting trade to X..."

# Post via OpenClaw browser
RESULT=$("$(dirname "$0")/post-tweet.sh" "$TWEET_TEXT")
echo "$RESULT"

# Report to platform
if [[ -n "${PLATFORM_API_KEY:-}" ]]; then
    "$(dirname "$0")/report-tweet.sh" "$RESULT"
fi
