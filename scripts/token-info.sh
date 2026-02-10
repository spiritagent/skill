#!/bin/bash
# Usage: token-info.sh <token_address>
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TOKEN_ADDRESS="$1"

if [[ -z "$TOKEN_ADDRESS" ]]; then
    echo "Usage: $0 <token_address>" >&2
    exit 1
fi

echo "📋 Fetching token info: $TOKEN_ADDRESS" >&2

# Get token data from DexScreener
RESPONSE=$(curl -s "https://api.dexscreener.com/tokens/v1/base/$TOKEN_ADDRESS" || echo '{"error":"API call failed"}')

if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ API error: $(echo "$RESPONSE" | jq -r '.error')" >&2
    exit 1
fi

# Check if we have pairs data
if ! echo "$RESPONSE" | jq -e '.pairs' >/dev/null 2>&1 || [ "$(echo "$RESPONSE" | jq '.pairs | length')" = "0" ]; then
    echo "❌ No trading pairs found for token" >&2
    echo '{
        "address": "'$TOKEN_ADDRESS'",
        "name": null,
        "symbol": null,
        "price_usd": 0,
        "market_cap": 0,
        "liquidity_usd": 0,
        "volume_24h": 0,
        "volume_6h": 0,
        "volume_1h": 0,
        "price_change_24h": 0,
        "price_change_6h": 0,
        "price_change_1h": 0,
        "txns_24h_buys": 0,
        "txns_24h_sells": 0,
        "pairs": [],
        "error": "NO_PAIRS"
    }'
    exit 0
fi

# Process and format the response
echo "$RESPONSE" | jq '
# Get all Base chain pairs
(.pairs | map(select(.chainId == "base"))) as $base_pairs |

# Get the best pair (highest liquidity)
($base_pairs | sort_by(.liquidity.usd) | reverse | .[0]) as $best_pair |

# Aggregate metrics across all Base pairs
($base_pairs | map(.liquidity.usd // 0) | add) as $total_liquidity |
($base_pairs | map(.volume.h24 // 0) | add) as $total_volume_24h |
($base_pairs | map(.volume.h6 // 0) | add) as $total_volume_6h |
($base_pairs | map(.volume.h1 // 0) | add) as $total_volume_1h |

{
    address: ($best_pair.baseToken.address // "unknown"),
    name: ($best_pair.baseToken.name // null),
    symbol: ($best_pair.baseToken.symbol // null),
    price_usd: ($best_pair.priceUsd // "0" | tonumber),
    market_cap: ($best_pair.marketCap // $best_pair.fdv // 0),
    fdv: ($best_pair.fdv // 0),
    liquidity_usd: $total_liquidity,
    volume_24h: $total_volume_24h,
    volume_6h: $total_volume_6h,
    volume_1h: $total_volume_1h,
    price_change_24h: ($best_pair.priceChange.h24 // 0),
    price_change_6h: ($best_pair.priceChange.h6 // 0),
    price_change_1h: ($best_pair.priceChange.h1 // 0),
    txns_24h_buys: ($best_pair.txns.h24.buys // 0),
    txns_24h_sells: ($best_pair.txns.h24.sells // 0),
    txns_6h_buys: ($best_pair.txns.h6.buys // 0),
    txns_6h_sells: ($best_pair.txns.h6.sells // 0),
    txns_1h_buys: ($best_pair.txns.h1.buys // 0),
    txns_1h_sells: ($best_pair.txns.h1.sells // 0),
    pair_created_at: ($best_pair.pairCreatedAt // null),
    pairs: $base_pairs | map({
        pair_address: .pairAddress,
        dex_id: .dexId,
        liquidity_usd: (.liquidity.usd // 0),
        volume_24h: (.volume.h24 // 0),
        quote_token: {
            address: .quoteToken.address,
            name: .quoteToken.name,
            symbol: .quoteToken.symbol
        }
    })
}'