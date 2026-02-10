#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

# Default parameters
LIMIT="${1:-20}"
SORT_BY="${2:-updated_at}"  # updated_at, circulating_market_cap, holder_count

echo "🔍 Scanning Base market for trending tokens..."

# Get trending tokens from Blockscout
RESPONSE=$(curl -s "https://base.blockscout.com/api/v2/tokens?limit=$LIMIT&sort=$SORT_BY&order=desc" \
    -H "Content-Type: application/json" || echo '{"error":"API call failed"}')

if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ API error: $(echo "$RESPONSE" | jq -r '.error')"
    exit 1
fi

# Filter and format results
echo "$RESPONSE" | jq -r '
.items[] | select(
    .type == "ERC-20" and
    (.circulating_market_cap // 0 | tonumber) > 0 and
    (.holder_count // 0 | tonumber) > 10
) | {
    address: .address,
    symbol: .symbol,
    name: .name,
    price_usd: (.exchange_rate // "0" | tonumber),
    market_cap: (.circulating_market_cap // "0" | tonumber),
    holders: (.holder_count // 0),
    updated: .updated_at,
    volume_24h: (.volume_24h // "0" | tonumber)
} | @json'