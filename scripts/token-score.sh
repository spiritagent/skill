#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TOKEN_ADDRESS="$1"
STRATEGY="${2:-$STRATEGY}"

if [[ -z "$TOKEN_ADDRESS" ]]; then
    echo "Usage: $0 <token_address> [strategy]"
    exit 1
fi

echo "📊 Scoring token: $TOKEN_ADDRESS"

# Load strategy config
STRATEGY_FILE="$(dirname "$0")/../strategies/${STRATEGY}.json"
if [[ ! -f "$STRATEGY_FILE" ]]; then
    echo "❌ Strategy not found: $STRATEGY"
    exit 1
fi

STRATEGY_CONFIG=$(cat "$STRATEGY_FILE")

# Get token info
TOKEN_INFO=$(curl -s "https://base.blockscout.com/api/v2/tokens/$TOKEN_ADDRESS" || echo '{"error":"failed"}')

if echo "$TOKEN_INFO" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ Failed to fetch token info"
    exit 1
fi

# Extract strategy thresholds
MIN_LIQUIDITY=$(echo "$STRATEGY_CONFIG" | jq -r '.minLiquidityUSD')
MIN_HOLDERS=$(echo "$STRATEGY_CONFIG" | jq -r '.minHolders')

# Calculate score
SCORE=$(echo "$TOKEN_INFO $STRATEGY_CONFIG" | jq -r '
.[0] as $token | .[1] as $strategy |

# Extract metrics
($token.circulating_market_cap // "0" | tonumber) as $market_cap |
($token.holder_count // 0) as $holders |
($token.volume_24h // "0" | tonumber) as $volume |
($strategy.minLiquidityUSD | tonumber) as $min_liq |
($strategy.minHolders | tonumber) as $min_holders |

# Calculate individual scores (0-100)
(if $market_cap >= $min_liq then 
    if $market_cap >= ($min_liq * 10) then 100
    else ($market_cap / $min_liq) * 10 end
 else 0 end) as $liquidity_score |

(if $holders >= $min_holders then
    if $holders >= ($min_holders * 10) then 100  
    else ($holders / $min_holders) * 10 end
 else 0 end) as $holder_score |

# Volume score (24h volume vs market cap ratio)
(if $market_cap > 0 then
    (($volume / $market_cap) * 100) | if . > 100 then 100 else . end
 else 0 end) as $volume_score |

# Age bonus (newer tokens get slight bonus for meme potential)
(now - ($token.updated_at // now | strptime("%Y-%m-%dT%H:%M:%S.%fZ") | mktime)) as $age_seconds |
($age_seconds / 86400) as $age_days |
(if $age_days < 1 then 20
 elif $age_days < 7 then 10
 elif $age_days < 30 then 5
 else 0 end) as $age_bonus |

# Combined score
(($liquidity_score * 0.4) + ($holder_score * 0.3) + ($volume_score * 0.2) + ($age_bonus * 0.1)) as $total_score |

{
    address: $token.address,
    symbol: $token.symbol,
    name: $token.name,
    score: ($total_score | floor),
    breakdown: {
        liquidity: ($liquidity_score | floor),
        holders: ($holder_score | floor),  
        volume: ($volume_score | floor),
        age_bonus: ($age_bonus | floor)
    },
    metrics: {
        market_cap_usd: $market_cap,
        holder_count: $holders,
        volume_24h_usd: $volume,
        age_days: ($age_days | floor)
    },
    meets_criteria: ($market_cap >= $min_liq and $holders >= $min_holders),
    recommendation: (
        if $total_score >= 80 then "STRONG_BUY"
        elif $total_score >= 60 then "BUY"  
        elif $total_score >= 40 then "WATCH"
        elif $total_score >= 20 then "WEAK"
        else "AVOID"
    )
}'
)

echo "$SCORE" | jq .