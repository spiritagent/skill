#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

# Default parameters
LIMIT="${1:-20}"

echo "🔍 Scanning Base market for trending tokens via DexScreener..." >&2

# Get top boosted tokens from DexScreener (trending indicators)
BOOSTED_RESPONSE=$(curl -s "https://api.dexscreener.com/token-boosts/top/v1" \
    -H "Content-Type: application/json" 2>/dev/null || echo '{"error":"API call failed"}')

if echo "$BOOSTED_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ Boosted tokens API error: $(echo "$BOOSTED_RESPONSE" | jq -r '.error')" >&2
else
    echo "📈 Found $(echo "$BOOSTED_RESPONSE" | jq -r '. | length') boosted tokens" >&2
fi

# Search for popular pairs on Base to get broader market view
SEARCH_RESPONSE=$(curl -s "https://api.dexscreener.com/latest/dex/search?q=base" \
    -H "Content-Type: application/json" 2>/dev/null || echo '{"error":"API call failed"}')

if echo "$SEARCH_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ Search API error: $(echo "$SEARCH_RESPONSE" | jq -r '.error')" >&2
    echo '[]'
    exit 1
fi

# Check if response has pairs
if ! echo "$SEARCH_RESPONSE" | jq -e '.pairs' >/dev/null 2>&1; then
    echo "❌ Invalid API response format" >&2
    echo '[]'
    exit 1
fi

# Filter for Base chain pairs and format results
echo "$SEARCH_RESPONSE" | jq --arg limit "$LIMIT" '
.pairs | map(select(
    .chainId == "base" and
    (.liquidity.usd // 0) > 1000 and
    (.volume.h24 // 0) > 100 and
    (.priceUsd // "0" | tonumber) > 0 and
    .baseToken.address != null
)) | sort_by(.volume.h24) | reverse | .[0:($limit | tonumber)] | map({
    address: .baseToken.address,
    symbol: .baseToken.symbol,
    name: .baseToken.name,
    price_usd: (.priceUsd // "0" | tonumber),
    market_cap: (.fdv // 0),
    liquidity_usd: (.liquidity.usd // 0),
    volume_24h: (.volume.h24 // 0),
    volume_6h: (.volume.h6 // 0),
    volume_1h: (.volume.h1 // 0),
    price_change_24h: (.priceChange.h24 // 0),
    price_change_6h: (.priceChange.h6 // 0),
    price_change_1h: (.priceChange.h1 // 0),
    txns_24h_buys: (.txns.h24.buys // 0),
    txns_24h_sells: (.txns.h24.sells // 0),
    pair_created_at: (.pairCreatedAt // null),
    pair_address: .pairAddress,
    dex_id: .dexId,
    updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
})'