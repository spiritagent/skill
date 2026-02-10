#!/bin/bash
# Usage: price.sh <token_address> <amount_in_wei> [direction]
# direction: buy (ETH→token, default) or sell (token→ETH)
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

TOKEN="$1"
AMOUNT="$2"
DIRECTION="${3:-buy}"
ADDRESS="${BASE_WALLET_ADDRESS}"
API_KEY="${GLUEX_API_KEY:-VtQwnrPU75cMIFFquIbZpiIyxFL0siqf}"
ETH="0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
PID="866a61811189692e8eccae5d2759724a812fa6f8703ebffe90c29dc1f886bbc1"

if [ "$DIRECTION" = "buy" ]; then
  INPUT="$ETH"
  OUTPUT="$TOKEN"
else
  INPUT="$TOKEN"
  OUTPUT="$ETH"
fi

curl -s -X POST "https://router.gluex.xyz/v1/price" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "origin: https://dapp.gluex.xyz" \
  -H "referer: https://dapp.gluex.xyz/" \
  -d "{
    \"inputToken\": \"$INPUT\",
    \"outputToken\": \"$OUTPUT\",
    \"inputAmount\": \"$AMOUNT\",
    \"userAddress\": \"$ADDRESS\",
    \"outputReceiver\": \"$ADDRESS\",
    \"chainID\": \"base\",
    \"uniquePID\": \"$PID\",
    \"isPermit2\": false,
    \"computeStable\": true,
    \"computeEstimate\": true,
    \"modulesFilter\": [],
    \"modulesDisabled\": [],
    \"activateSurplusFee\": false
  }" | jq '{
    inputAmount: .result.inputAmount,
    outputAmount: .result.outputAmount,
    inputUSD: .result.inputAmountUSD,
    outputUSD: .result.outputAmountUSD,
    minOutput: .result.minOutputAmount,
    route: .result.liquidityModules,
    router: .result.router
  }'
