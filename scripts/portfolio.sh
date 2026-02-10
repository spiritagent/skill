#!/bin/bash
# Usage: portfolio.sh [address]
# Outputs portfolio data as JSON
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ADDRESS="${1:-$BASE_WALLET_ADDRESS}"
BLOCKSCOUT="https://base.blockscout.com/api/v2"

if [ -z "$ADDRESS" ]; then
    echo "Error: No wallet address specified" >&2
    exit 1
fi

# Get ETH balance
eth_data=$(curl -s "$BLOCKSCOUT/addresses/$ADDRESS" || { echo "Failed to fetch ETH balance" >&2; exit 1; })
eth_balance=$(echo "$eth_data" | jq -r '.coin_balance // "0"' | awk '{printf "%.6f", $1/1e18}')
eth_price_usd=$(echo "$eth_data" | jq -r '.exchange_rate // "0"')
eth_balance_usd=$(awk -v bal="$eth_balance" -v price="$eth_price_usd" 'BEGIN {printf "%.2f", bal * price}')

# Get token balances
tokens_data=$(curl -s "$BLOCKSCOUT/addresses/$ADDRESS/tokens?type=ERC-20" || { echo "Failed to fetch tokens" >&2; exit 1; })

# Build JSON output
jq -n \
  --arg address "$ADDRESS" \
  --arg eth_balance "$eth_balance" \
  --arg eth_balance_usd "$eth_balance_usd" \
  --argjson tokens_raw "$tokens_data" \
  '{
    address: $address,
    eth_balance: $eth_balance,
    eth_balance_usd: $eth_balance_usd,
    tokens: [
      $tokens_raw.items[]? |
      select((.value | tonumber) > 0) |
      {
        token_address: .token.address,
        token_symbol: .token.symbol,
        balance: (.value | tonumber / pow(10; .token.decimals | tonumber) | tostring),
        value_usd: (if .token.exchange_rate then ((.value | tonumber / pow(10; .token.decimals | tonumber)) * (.token.exchange_rate | tonumber) | tostring) else "0.00" end)
      }
    ]
  }'