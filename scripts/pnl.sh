#!/bin/bash
# Fetch PnL from platform (server-computed, trustless)
# Usage: pnl.sh [agent_id]
set -euo pipefail

source "$(dirname "$0")/../.env"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured" >&2
    echo '{"realized_pnl": "0", "unrealized_pnl": "0", "total_pnl": "0", "trades_count": 0}'
    exit 0
fi

# Get agent info to find agent ID
AGENT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    "$PLATFORM_API_URL/api/v1/agents/me" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$AGENT_RESPONSE" | tail -1)
AGENT_BODY=$(echo "$AGENT_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
    echo "❌ Failed to fetch agent info" >&2
    echo '{"realized_pnl": "0", "unrealized_pnl": "0", "total_pnl": "0", "trades_count": 0}'
    exit 0
fi

AGENT_ID=$(echo "$AGENT_BODY" | jq -r '.data.agent.id // empty')

if [[ -z "$AGENT_ID" ]]; then
    echo "❌ No agent ID found" >&2
    echo '{"realized_pnl": "0", "unrealized_pnl": "0", "total_pnl": "0", "trades_count": 0}'
    exit 0
fi

# Fetch portfolio with server-computed PnL
PORTFOLIO_RESPONSE=$(curl -s -w "\n%{http_code}" \
    "$PLATFORM_API_URL/api/v1/agents/$AGENT_ID/portfolio" 2>/dev/null || echo -e "\n000")

P_HTTP_CODE=$(echo "$PORTFOLIO_RESPONSE" | tail -1)
P_BODY=$(echo "$PORTFOLIO_RESPONSE" | sed '$d')

if [[ "$P_HTTP_CODE" == "200" ]]; then
    echo "$P_BODY" | jq '.data | {
        realized_pnl: .realized_pnl_usd,
        unrealized_pnl: .unrealized_pnl_usd,
        total_pnl: .total_pnl_usd,
        trades_count: .total_trades,
        pnl_updated_at: .pnl_updated_at,
        positions: [.positions[]? | {
            token: .token_address,
            symbol: .symbol,
            amount: .amount,
            cost_basis: .cost_basis_usd,
            realized_pnl: .realized_pnl_usd
        }]
    }'
else
    echo "❌ Failed to fetch portfolio (HTTP $P_HTTP_CODE)" >&2
    echo '{"realized_pnl": "0", "unrealized_pnl": "0", "total_pnl": "0", "trades_count": 0}'
fi
