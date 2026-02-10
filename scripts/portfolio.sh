#!/bin/bash
# Usage: portfolio.sh [address]
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ADDRESS="${1:-$BASE_WALLET_ADDRESS}"
BLOCKSCOUT="https://base.blockscout.com/api/v2"

echo "=== Portfolio for $ADDRESS ==="
echo ""

# ETH balance
echo "--- ETH ---"
curl -s "$BLOCKSCOUT/addresses/$ADDRESS" | jq -r '"Balance: " + (.coin_balance | tonumber / 1e18 | tostring) + " ETH"'
echo ""

# Token balances
echo "--- Tokens ---"
curl -s "$BLOCKSCOUT/addresses/$ADDRESS/tokens?type=ERC-20" | jq -r '
  .items[] | select((.value | tonumber) > 0) |
  .token.symbol + ": " + (.value | tonumber / pow(10; .token.decimals | tonumber) | tostring) +
  (if .token.exchange_rate then " ($" + .token.exchange_rate + ")" else "" end)
'
