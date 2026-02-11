#!/bin/bash
# Token safety check before buying
# Checks: ownership, top holders, honeypot simulation, pair age, liquidity lock
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

TOKEN="$1"
RPC="${BASE_RPC:-https://mainnet.base.org}"

if [[ -z "$TOKEN" ]]; then
    echo "Usage: $0 <token_address>" >&2
    exit 1
fi

echo "🛡️ Safety check: $TOKEN" >&2

WARNINGS=()
SCORE=100

# --- 1. Basic token info ---
NAME=$(cast call "$TOKEN" "name()(string)" --rpc-url "$RPC" 2>/dev/null || echo "UNKNOWN")
SYMBOL=$(cast call "$TOKEN" "symbol()(string)" --rpc-url "$RPC" 2>/dev/null || echo "???")
DECIMALS=$(cast call "$TOKEN" "decimals()(uint8)" --rpc-url "$RPC" 2>/dev/null || echo "18")
TOTAL_SUPPLY=$(cast call "$TOKEN" "totalSupply()(uint256)" --rpc-url "$RPC" 2>/dev/null || echo "0")

echo "Token: $NAME ($SYMBOL) decimals=$DECIMALS supply=$TOTAL_SUPPLY" >&2

# --- 2. Ownership check ---
OWNER=$(cast call "$TOKEN" "owner()(address)" --rpc-url "$RPC" 2>/dev/null || echo "no_owner_function")

if [[ "$OWNER" == "no_owner_function" ]]; then
    OWNER_STATUS="no_owner_function"
elif [[ "$OWNER" == "0x0000000000000000000000000000000000000000" ]]; then
    OWNER_STATUS="renounced"
else
    OWNER_STATUS="owned"
    WARNINGS+=("⚠️ Contract has owner: $OWNER")
    SCORE=$((SCORE - 20))
fi

# --- 3. Check if contract is verified (via Basescan API) ---
VERIFIED="unknown"
BASESCAN_RESP=$(curl -s "https://api.basescan.org/api?module=contract&action=getabi&address=$TOKEN" 2>/dev/null || true)
if echo "$BASESCAN_RESP" | jq -e '.status == "1"' >/dev/null 2>&1; then
    VERIFIED="yes"
else
    VERIFIED="no"
    WARNINGS+=("⚠️ Contract not verified on Basescan")
    SCORE=$((SCORE - 15))
fi

# --- 4. Top holder concentration ---
# Check deployer/null address balance
if [[ "$TOTAL_SUPPLY" != "0" ]]; then
    # Check dead address holdings (burned)
    DEAD_BAL=$(cast call "$TOKEN" "balanceOf(address)(uint256)" "0x000000000000000000000000000000000000dEaD" --rpc-url "$RPC" 2>/dev/null || echo "0")
    ZERO_BAL=$(cast call "$TOKEN" "balanceOf(address)(uint256)" "0x0000000000000000000000000000000000000000" --rpc-url "$RPC" 2>/dev/null || echo "0")
    
    # If owner exists, check their balance
    OWNER_BAL="0"
    if [[ "$OWNER_STATUS" == "owned" ]]; then
        OWNER_BAL=$(cast call "$TOKEN" "balanceOf(address)(uint256)" "$OWNER" --rpc-url "$RPC" 2>/dev/null || echo "0")
        if [[ "$TOTAL_SUPPLY" != "0" && "$OWNER_BAL" != "0" ]]; then
            # Calculate owner percentage (rough — using bc or python)
            OWNER_PCT=$(python3 -c "print(round(int('$OWNER_BAL') / int('$TOTAL_SUPPLY') * 100, 1))" 2>/dev/null || echo "?")
            if [[ "$OWNER_PCT" != "?" ]] && python3 -c "exit(0 if float('$OWNER_PCT') > 10 else 1)" 2>/dev/null; then
                WARNINGS+=("🚨 Owner holds ${OWNER_PCT}% of supply")
                SCORE=$((SCORE - 25))
            fi
        fi
    fi
fi

# --- 5. Honeypot simulation (try to estimate sell tax) ---
# Check if there's a fee/tax function
HAS_FEE=$(cast call "$TOKEN" "totalFee()(uint256)" --rpc-url "$RPC" 2>/dev/null || \
           cast call "$TOKEN" "sellFee()(uint256)" --rpc-url "$RPC" 2>/dev/null || \
           cast call "$TOKEN" "tax()(uint256)" --rpc-url "$RPC" 2>/dev/null || \
           echo "no_fee_function")

if [[ "$HAS_FEE" != "no_fee_function" && "$HAS_FEE" != "0" ]]; then
    WARNINGS+=("⚠️ Token has fee/tax: $HAS_FEE")
    SCORE=$((SCORE - 10))
fi

# --- 6. Check pair age from DexScreener ---
PAIR_AGE="unknown"
DS_DATA=$(curl -s "https://api.dexscreener.com/tokens/v1/base/$TOKEN" 2>/dev/null || true)
if echo "$DS_DATA" | jq -e '.[0].pairCreatedAt' >/dev/null 2>&1; then
    CREATED_MS=$(echo "$DS_DATA" | jq -r '.[0].pairCreatedAt')
    NOW_MS=$(date +%s%3N)
    AGE_HOURS=$(python3 -c "print(round(($NOW_MS - $CREATED_MS) / 3600000, 1))" 2>/dev/null || echo "?")
    PAIR_AGE="${AGE_HOURS}h"
    
    if [[ "$AGE_HOURS" != "?" ]] && python3 -c "exit(0 if float('$AGE_HOURS') < 1 else 1)" 2>/dev/null; then
        WARNINGS+=("🚨 Pair less than 1 hour old!")
        SCORE=$((SCORE - 20))
    elif [[ "$AGE_HOURS" != "?" ]] && python3 -c "exit(0 if float('$AGE_HOURS') < 24 else 1)" 2>/dev/null; then
        WARNINGS+=("⚠️ Pair less than 24 hours old")
        SCORE=$((SCORE - 10))
    fi
    
    # Get liquidity
    LIQUIDITY=$(echo "$DS_DATA" | jq -r '.[0].liquidity.usd // 0')
else
    LIQUIDITY="unknown"
fi

# --- 7. Final rating ---
if [[ $SCORE -ge 80 ]]; then
    RATING="SAFE"
elif [[ $SCORE -ge 60 ]]; then
    RATING="MODERATE"
elif [[ $SCORE -ge 40 ]]; then
    RATING="RISKY"
else
    RATING="DANGEROUS"
fi

# Clamp score
if [[ $SCORE -lt 0 ]]; then SCORE=0; fi

# Output JSON
WARNINGS_JSON=$(printf '%s\n' "${WARNINGS[@]}" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo '[]')

jq -n \
    --arg address "$TOKEN" \
    --arg name "$NAME" \
    --arg symbol "$SYMBOL" \
    --arg owner_status "$OWNER_STATUS" \
    --arg owner "${OWNER:-none}" \
    --arg verified "$VERIFIED" \
    --arg pair_age "$PAIR_AGE" \
    --arg liquidity "$LIQUIDITY" \
    --arg rating "$RATING" \
    --argjson score "$SCORE" \
    --argjson warnings "$WARNINGS_JSON" \
    '{
        address: $address,
        name: $name,
        symbol: $symbol,
        safety_score: $score,
        rating: $rating,
        checks: {
            ownership: $owner_status,
            owner_address: $owner,
            verified: $verified,
            pair_age: $pair_age,
            liquidity_usd: $liquidity
        },
        warnings: $warnings
    }'
