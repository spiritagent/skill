#!/bin/bash
# Usage: balance.sh [address] [token_address]
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ADDRESS="${1:-$BASE_WALLET_ADDRESS}"
TOKEN="${2:-}"
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
