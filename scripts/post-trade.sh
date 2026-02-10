#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

TRADE_DATA="$1"

if [[ -z "$TRADE_DATA" ]]; then
    echo "Usage: $0 '<trade_json>'" >&2
    exit 1
fi

echo "🐦 Formatting trade tweet..." >&2

# Parse trade data
ACTION=$(echo "$TRADE_DATA" | jq -r '.action')
SYMBOL=$(echo "$TRADE_DATA" | jq -r '.symbol')
AMOUNT_IN_USD=$(echo "$TRADE_DATA" | jq -r '.amountInUSD // .amount_in_usd // "0"')
AMOUNT_OUT_USD=$(echo "$TRADE_DATA" | jq -r '.amountOutUSD // .amount_out_usd // "0"')
TX_HASH=$(echo "$TRADE_DATA" | jq -r '.txHash // .tx_hash // ""')

case "$ACTION" in
    "buy")  EMOJI="🚀"; ACTION_TEXT="Bought" ;;
    "sell") EMOJI="💰"; ACTION_TEXT="Sold" ;;
    *)      EMOJI="📈"; ACTION_TEXT="Traded" ;;
esac

# Format amounts for display
AMOUNT_IN_DISPLAY=$(echo "$AMOUNT_IN_USD" | awk '{printf "%.2f", $1}')
AMOUNT_OUT_DISPLAY=$(echo "$AMOUNT_OUT_USD" | awk '{printf "%.2f", $1}')

TWEET_TEXT="$EMOJI $ACTION_TEXT \$$SYMBOL

💵 Value: \$${AMOUNT_IN_DISPLAY} → \$${AMOUNT_OUT_DISPLAY}
🔗 TX: https://basescan.org/tx/${TX_HASH}

#Base #DeFi #Crypto #Trading"

# Truncate if too long
if [[ ${#TWEET_TEXT} -gt 280 ]]; then
    TWEET_TEXT="$EMOJI $ACTION_TEXT \$$SYMBOL - \$${AMOUNT_IN_DISPLAY} → \$${AMOUNT_OUT_DISPLAY}

🔗 https://basescan.org/tx/${TX_HASH}

#Base #DeFi"
fi

# Post via twikit
python3 "$(dirname "$0")/twitter.py" post "$TWEET_TEXT"