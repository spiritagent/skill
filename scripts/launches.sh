#!/bin/bash
# Fetch agent's token launches with live market data from DexScreener
set -euo pipefail
source "$(dirname "$0")/../.env" 2>/dev/null || true

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "No launches."
    exit 0
fi

LAUNCHES=$(curl -s -H "Authorization: Bearer $PLATFORM_API_KEY" \
    "$PLATFORM_API_URL/api/v1/launches?limit=20" 2>/dev/null)

COUNT=$(echo "$LAUNCHES" | jq -r '.data | length' 2>/dev/null || echo "0")
if [[ "$COUNT" == "0" || "$COUNT" == "null" ]]; then
    echo "No launches yet."
    exit 0
fi

# For each launch, fetch market data from DexScreener
echo "$LAUNCHES" | jq -r '.data[]? | "\(.symbol)|\(.name)|\(.tokenAddress)|\(.status)|\(.launchedAt)"' 2>/dev/null | while IFS='|' read -r SYMBOL NAME ADDR STATUS LAUNCHED; do
    if [[ -z "$ADDR" || "$ADDR" == "null" ]]; then
        echo "[$SYMBOL] $NAME | Status: $STATUS | Launched: $LAUNCHED"
        continue
    fi

    # Fetch live market data
    DEX=$(curl -s "https://api.dexscreener.com/tokens/v1/base/$ADDR" 2>/dev/null)
    PRICE=$(echo "$DEX" | jq -r '.[0].priceUsd // "?"' 2>/dev/null)
    MC=$(echo "$DEX" | jq -r '.[0].marketCap // .[0].fdv // "?"' 2>/dev/null)
    LIQ=$(echo "$DEX" | jq -r '.[0].liquidity.usd // "?"' 2>/dev/null)
    VOL24=$(echo "$DEX" | jq -r '.[0].volume.h24 // "?"' 2>/dev/null)
    CHG24=$(echo "$DEX" | jq -r '.[0].priceChange.h24 // "?"' 2>/dev/null)
    HOLDERS=$(echo "$DEX" | jq -r '.[0].holders // "?"' 2>/dev/null)

    echo "[$SYMBOL] $NAME | $ADDR | Price: \$$PRICE | MC: \$$MC | Liq: \$$LIQ | Vol24h: \$$VOL24 | 24h: ${CHG24}% | Launched: $LAUNCHED"
done
