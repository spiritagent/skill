#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TRADES_FILE="$(dirname "$0")/../data/trades.jsonl"

# Parse arguments
ACTION="$1"
TOKEN_ADDRESS="$2"
SYMBOL="$3"
AMOUNT_IN="$4"
AMOUNT_IN_USD="$5"
AMOUNT_OUT="$6"
AMOUNT_OUT_USD="$7"
TX_HASH="$8"
ROUTE="${9:-unknown}"

if [[ $# -lt 8 ]]; then
    echo "Usage: $0 <action> <token_address> <symbol> <amount_in> <amount_in_usd> <amount_out> <amount_out_usd> <tx_hash> [route]"
    exit 1
fi

echo "📝 Logging trade to $TRADES_FILE..."

# Create trade log entry
TRADE_ENTRY=$(jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg action "$ACTION" \
    --arg token "$TOKEN_ADDRESS" \
    --arg symbol "$SYMBOL" \
    --arg amountIn "$AMOUNT_IN" \
    --arg amountInUSD "$AMOUNT_IN_USD" \
    --arg amountOut "$AMOUNT_OUT" \
    --arg amountOutUSD "$AMOUNT_OUT_USD" \
    --arg txHash "$TX_HASH" \
    --arg route "$ROUTE" \
    '{
        ts: $ts,
        action: $action,
        token: $token,
        symbol: $symbol,
        amountIn: $amountIn,
        amountInUSD: $amountInUSD,
        amountOut: $amountOut,
        amountOutUSD: $amountOutUSD,
        txHash: $txHash,
        route: [$route],
        pnl: null
    }'
)

# Append to trades file
echo "$TRADE_ENTRY" >> "$TRADES_FILE"

echo "✅ Trade logged: $ACTION $SYMBOL ($AMOUNT_IN_USD USD)"
echo "$TRADE_ENTRY" | jq .