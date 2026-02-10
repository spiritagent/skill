#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TOKEN_ADDRESS="$1"
STRATEGY="${2:-$STRATEGY}"

if [[ -z "$TOKEN_ADDRESS" ]]; then
    echo "Usage: $0 <token_address> [strategy]" >&2
    exit 1
fi

echo "📊 Scoring token: $TOKEN_ADDRESS" >&2

# Load strategy config
STRATEGY_FILE="$(dirname "$0")/../strategies/${STRATEGY}.json"
if [[ ! -f "$STRATEGY_FILE" ]]; then
    echo "❌ Strategy not found: $STRATEGY" >&2
    exit 1
fi

STRATEGY_CONFIG=$(cat "$STRATEGY_FILE")

# Get token data from DexScreener
TOKEN_INFO=$(curl -s "https://api.dexscreener.com/tokens/v1/base/$TOKEN_ADDRESS" || echo '{"error":"failed"}')

if echo "$TOKEN_INFO" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ Failed to fetch token info from DexScreener" >&2
    echo '{
        "address": "'$TOKEN_ADDRESS'",
        "symbol": "UNKNOWN",
        "name": "Unknown Token",
        "score": 0,
        "breakdown": {
            "liquidity": 0,
            "volume": 0,
            "price_action": 0,
            "txn_activity": 0
        },
        "metrics": {
            "liquidity_usd": 0,
            "volume_24h_usd": 0,
            "price_change_24h": 0,
            "txns_24h": 0
        },
        "meets_criteria": false,
        "recommendation": "AVOID",
        "error": "API_FAILED"
    }'
    exit 0
fi

# Check if we have pairs data
if ! echo "$TOKEN_INFO" | jq -e '.pairs' >/dev/null 2>&1 || [ "$(echo "$TOKEN_INFO" | jq '.pairs | length')" = "0" ]; then
    echo "❌ No trading pairs found for token" >&2
    echo '{
        "address": "'$TOKEN_ADDRESS'",
        "symbol": "UNKNOWN", 
        "name": "Unknown Token",
        "score": 0,
        "breakdown": {
            "liquidity": 0,
            "volume": 0,
            "price_action": 0,
            "txn_activity": 0
        },
        "metrics": {
            "liquidity_usd": 0,
            "volume_24h_usd": 0,
            "price_change_24h": 0,
            "txns_24h": 0
        },
        "meets_criteria": false,
        "recommendation": "AVOID",
        "error": "NO_PAIRS"
    }'
    exit 0
fi

# Get the best pair (highest liquidity) for Base chain
BEST_PAIR=$(echo "$TOKEN_INFO" | jq '.pairs | map(select(.chainId == "base")) | sort_by(.liquidity.usd) | reverse | .[0]')

if [ "$BEST_PAIR" = "null" ]; then
    echo "❌ No Base chain pairs found" >&2
    echo '{
        "address": "'$TOKEN_ADDRESS'",
        "symbol": "UNKNOWN",
        "name": "Unknown Token", 
        "score": 0,
        "breakdown": {
            "liquidity": 0,
            "volume": 0,
            "price_action": 0,
            "txn_activity": 0
        },
        "metrics": {
            "liquidity_usd": 0,
            "volume_24h_usd": 0,
            "price_change_24h": 0,
            "txns_24h": 0
        },
        "meets_criteria": false,
        "recommendation": "AVOID",
        "error": "NO_BASE_PAIRS"
    }'
    exit 0
fi

# Calculate score using DexScreener data
SCORE=$(jq -n \
    --argjson pair "$BEST_PAIR" \
    --argjson strategy "$STRATEGY_CONFIG" \
    '
# Extract metrics from best pair
($pair.liquidity.usd // 0) as $liquidity |
($pair.volume.h24 // 0) as $volume_24h |
($pair.priceChange.h24 // 0) as $price_change_24h |
(($pair.txns.h24.buys // 0) + ($pair.txns.h24.sells // 0)) as $txns_24h |
($pair.fdv // 0) as $market_cap |
($strategy.minLiquidityUSD | tonumber) as $min_liq |

# Calculate individual scores (0-100)

# Liquidity score (40% weight)
(if $liquidity >= $min_liq then 
    if $liquidity >= ($min_liq * 10) then 100
    else (($liquidity / $min_liq) * 10) | if . > 100 then 100 else . end
    end
 else 0 end) as $liquidity_score |

# Volume score (30% weight) - 24h volume vs liquidity ratio
(if $liquidity > 0 then
    (($volume_24h / $liquidity) * 20) | if . > 100 then 100 else . end
 else 0 end) as $volume_score |

# Price action score (20% weight) - positive momentum
(if $price_change_24h > 0 then
    if $price_change_24h > 50 then 100
    else ($price_change_24h * 2) | if . > 100 then 100 else . end
    end
 elif $price_change_24h > -10 then 20
 else 0 end) as $price_score |

# Transaction activity score (10% weight)
(if $txns_24h > 100 then 100
 elif $txns_24h > 10 then ($txns_24h / 100) * 100
 else ($txns_24h * 5) | if . > 100 then 100 else . end 
 end) as $txn_score |

# Combined weighted score  
(($liquidity_score * 0.4) + ($volume_score * 0.3) + ($price_score * 0.2) + ($txn_score * 0.1)) as $total_score |

# Age consideration (newer pairs might be riskier)
(if ($pair.pairCreatedAt // null) then
    ((now - ($pair.pairCreatedAt / 1000)) / 86400) as $age_days |
    if $age_days < 1 then ($total_score * 0.8)  # 20% penalty for very new
    elif $age_days < 7 then ($total_score * 0.9)  # 10% penalty for new  
    else $total_score
    end
 else $total_score
 end) as $final_score |

{
    address: ($pair.baseToken.address // "'$TOKEN_ADDRESS'"),
    symbol: ($pair.baseToken.symbol // "UNKNOWN"),
    name: ($pair.baseToken.name // "Unknown Token"),
    score: ($final_score | floor),
    breakdown: {
        liquidity: ($liquidity_score | floor),
        volume: ($volume_score | floor),
        price_action: ($price_score | floor),
        txn_activity: ($txn_score | floor)
    },
    metrics: {
        liquidity_usd: $liquidity,
        volume_24h_usd: $volume_24h,
        price_change_24h: $price_change_24h,
        txns_24h: $txns_24h,
        market_cap: $market_cap,
        age_days: (if ($pair.pairCreatedAt // null) then ((now - ($pair.pairCreatedAt / 1000)) / 86400) | floor else null end)
    },
    meets_criteria: ($liquidity >= $min_liq and $txns_24h >= 10),
    recommendation: (
        if $final_score >= 80 then "STRONG_BUY"
        elif $final_score >= 60 then "BUY"  
        elif $final_score >= 40 then "WATCH"
        elif $final_score >= 20 then "WEAK"
        else "AVOID"
    ),
    pair_address: $pair.pairAddress,
    dex: $pair.dexId
}'
)

echo "$SCORE" | jq .