#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

WATCHLIST_FILE="$(dirname "$0")/../data/watchlist.json"

ACTION="$1"
TOKEN_ADDRESS="${2:-}"

case "$ACTION" in
    "add")
        if [[ -z "$TOKEN_ADDRESS" ]]; then
            echo "Usage: $0 add <token_address>"
            exit 1
        fi
        
        echo "🔍 Adding $TOKEN_ADDRESS to watchlist..."
        
        # Get token info from DexScreener
        TOKEN_RAW=$(curl -s "https://api.dexscreener.com/tokens/v1/base/$TOKEN_ADDRESS" || echo '[]')
        BEST_PAIR=$(echo "$TOKEN_RAW" | jq '[.[] | select(.chainId == "base")] | sort_by(.liquidity.usd) | reverse | .[0] // empty' 2>/dev/null)
        
        if [[ -z "$BEST_PAIR" || "$BEST_PAIR" == "null" ]]; then
            echo "❌ Token not found on DexScreener"
            exit 1
        fi
        
        SYMBOL=$(echo "$BEST_PAIR" | jq -r '.baseToken.symbol // "UNKNOWN"')
        NAME=$(echo "$BEST_PAIR" | jq -r '.baseToken.name // "Unknown"')
        
        # Add to watchlist
        CURRENT=$(cat "$WATCHLIST_FILE")
        UPDATED=$(echo "$CURRENT" | jq \
            --arg address "$TOKEN_ADDRESS" \
            --arg symbol "$SYMBOL" \
            --arg name "$NAME" \
            '
            .tokens |= (map(select(.address != $address)) + [{
                address: $address,
                symbol: $symbol,
                name: $name,
                added_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            }]) |
            .lastUpdated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            '
        )
        
        echo "$UPDATED" > "$WATCHLIST_FILE"
        echo "✅ Added $SYMBOL ($NAME) to watchlist"
        ;;
        
    "remove")
        if [[ -z "$TOKEN_ADDRESS" ]]; then
            echo "Usage: $0 remove <token_address>"
            exit 1
        fi
        
        echo "🗑️ Removing $TOKEN_ADDRESS from watchlist..."
        
        CURRENT=$(cat "$WATCHLIST_FILE")
        UPDATED=$(echo "$CURRENT" | jq \
            --arg address "$TOKEN_ADDRESS" \
            '
            .tokens |= map(select(.address != $address)) |
            .lastUpdated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            '
        )
        
        echo "$UPDATED" > "$WATCHLIST_FILE"
        echo "✅ Removed $TOKEN_ADDRESS from watchlist"
        ;;
        
    "list")
        echo "📝 Current watchlist:"
        cat "$WATCHLIST_FILE" | jq -r '
            if (.tokens | length) == 0 then
                "No tokens in watchlist"
            else
                .tokens[] | "  \(.symbol) (\(.name)) - \(.address) [added: \(.added_at)]"
            end
        '
        ;;
        
    "clear")
        echo "🗑️ Clearing watchlist..."
        echo '{"tokens": [], "lastUpdated": null}' > "$WATCHLIST_FILE"
        echo "✅ Watchlist cleared"
        ;;
        
    "score")
        if [[ -z "$TOKEN_ADDRESS" ]]; then
            echo "Usage: $0 score <token_address>"
            exit 1
        fi
        
        "$(dirname "$0")/token-score.sh" "$TOKEN_ADDRESS"
        ;;
        
    *)
        echo "Usage: $0 {add|remove|list|clear|score} [token_address]"
        echo
        echo "Commands:"
        echo "  add <address>    Add token to watchlist"
        echo "  remove <address> Remove token from watchlist" 
        echo "  list            Show all watched tokens"
        echo "  clear           Remove all tokens"
        echo "  score <address>  Score a token"
        exit 1
        ;;
esac