#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TRADES_FILE="$(dirname "$0")/../data/trades.jsonl"

echo "📊 Calculating PnL..."

if [[ ! -f "$TRADES_FILE" || ! -s "$TRADES_FILE" ]]; then
    echo "No trades found"
    echo '{"realized_pnl": 0, "unrealized_pnl": 0, "total_pnl": 0, "trades_count": 0}'
    exit 0
fi

# Get current portfolio for unrealized PnL
PORTFOLIO_DATA=$("$(dirname "$0")/portfolio.sh" "$BASE_WALLET_ADDRESS" 2>/dev/null || echo '{"tokens":[]}')

# Calculate realized PnL from trades
REALIZED_PNL=$(cat "$TRADES_FILE" | jq -s '
map(select(.pnl != null)) | 
map(.pnl | tonumber) | 
if length > 0 then add else 0 end
')

# Calculate unrealized PnL for current positions
UNREALIZED_DATA=$(cat "$TRADES_FILE" "$PORTFOLIO_DATA" | jq -s '
# Group trades by token
.[0] as $trades | .[1] as $portfolio |

# Get net position for each token
($trades | group_by(.token) | map({
    token: .[0].token,
    symbol: .[0].symbol,
    net_amount: (map(
        if .action == "buy" then (.amountOut | tonumber)
        else -(.amountIn | tonumber) end
    ) | add // 0),
    total_cost: (map(
        if .action == "buy" then (.amountInUSD | tonumber)
        else -(.amountOutUSD | tonumber) end
    ) | add // 0)
})) as $positions |

# Calculate unrealized PnL for positions with current holdings
$positions | map(
    . as $pos |
    # Find current holding
    ($portfolio.tokens[] | select(.token_address == $pos.token)) as $holding |
    if $holding and $pos.net_amount > 0 then
        # Calculate unrealized PnL
        (($holding.value_usd // 0 | tonumber) - $pos.total_cost)
    else
        0
    end
) | add // 0
')

TOTAL_PNL=$(echo "$REALIZED_PNL $UNREALIZED_DATA" | jq -s 'add')

# Count total trades
TRADES_COUNT=$(cat "$TRADES_FILE" | wc -l)

# Get trade statistics
STATS=$(cat "$TRADES_FILE" | jq -s '
{
    total_volume_usd: (map(.amountInUSD | tonumber) | add // 0),
    winning_trades: (map(select(.pnl and (.pnl | tonumber) > 0)) | length),
    losing_trades: (map(select(.pnl and (.pnl | tonumber) < 0)) | length),
    best_trade: (map(select(.pnl) | .pnl | tonumber) | max // 0),
    worst_trade: (map(select(.pnl) | .pnl | tonumber) | min // 0),
    avg_trade_size: (map(.amountInUSD | tonumber) | add / length // 0)
}
')

# Combine results
jq -n \
    --argjson realized "$REALIZED_PNL" \
    --argjson unrealized "$UNREALIZED_DATA" \
    --argjson total "$TOTAL_PNL" \
    --argjson trades_count "$TRADES_COUNT" \
    --argjson stats "$STATS" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        realized_pnl: $realized,
        unrealized_pnl: $unrealized,  
        total_pnl: $total,
        trades_count: $trades_count,
        statistics: $stats,
        timestamp: $timestamp
    }'