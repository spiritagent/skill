#!/bin/bash
# Usage: balance.sh [address] [token_address]
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ADDRESS="${1:-$BASE_WALLET_ADDRESS}"
TOKEN="${2:-}"

# Try platform endpoint first if configured
if [[ -n "${PLATFORM_API_URL:-}" && -n "${PLATFORM_API_KEY:-}" ]]; then
    RESPONSE=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer $PLATFORM_API_KEY" \
        "$PLATFORM_API_URL/api/v1/wallet/balance?address=$ADDRESS" 2>/dev/null || echo "000")
    
    HTTP_CODE="${RESPONSE: -3}"
    RESPONSE_BODY="${RESPONSE%???}"
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        BALANCE_DATA=$(echo "$RESPONSE_BODY" | jq '.data')
        
        if [ -z "$TOKEN" ]; then
            # Show ETH balance
            echo "$BALANCE_DATA" | jq '{
                address: .address,
                eth_balance: (.eth_balance + " ETH"),
                usd_value: .eth_balance_usd
            }'
        else
            # Show specific token balance
            echo "$BALANCE_DATA" | jq --arg token "$TOKEN" '
                .tokens[] | select(.token_address == ($token | ascii_downcase)) | {
                    token: .token_symbol,
                    address: .token_address,
                    balance: .balance,
                    usd_value: .value_usd
                }
            '
        fi
        exit 0
    else
        echo "⚠️  Platform balance endpoint failed, falling back to direct Blockscout..." >&2
    fi
fi

# Fallback to direct Blockscout call
BLOCKSCOUT="https://base.blockscout.com/api/v2"

if [ -z "$TOKEN" ]; then
  # ETH balance
  curl -s "$BLOCKSCOUT/addresses/$ADDRESS" | jq '{
    address: .hash,
    eth_balance: (.coin_balance | tonumber / 1e18 | tostring + " ETH"),
    usd_value: .exchange_rate
  }'
else
  # Token balance — get from token list
  curl -s "$BLOCKSCOUT/addresses/$ADDRESS/tokens?type=ERC-20" | jq --arg token "$TOKEN" '
    .items[] | select(.token.address == ($token | ascii_downcase)) | {
      token: .token.symbol,
      name: .token.name,
      balance: (.value | tonumber / pow(10; .token.decimals | tonumber) | tostring),
      usd_value: .token.exchange_rate
    }
  '
fi
