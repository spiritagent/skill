#!/bin/bash
# Usage: token-info.sh <token_address>
set -euo pipefail

TOKEN="$1"
BLOCKSCOUT="https://base.blockscout.com/api/v2"

curl -s "$BLOCKSCOUT/tokens/$TOKEN" | jq '{
  name: .name,
  symbol: .symbol,
  decimals: .decimals,
  total_supply: .total_supply,
  holders: .holders,
  exchange_rate: .exchange_rate,
  type: .type,
  address: .address
}'
