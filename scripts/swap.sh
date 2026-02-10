#!/bin/bash
# Usage: swap.sh <buy|sell> <token_address> <amount_in_wei> [slippage_bps]
# slippage_bps: default 100 (1%)
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ACTION="$1"
TOKEN="$2"
AMOUNT="$3"
SLIPPAGE="${4:-100}"
ADDRESS="${BASE_WALLET_ADDRESS}"
RPC="${BASE_RPC:-https://mainnet.base.org}"
API_KEY="${GLUEX_API_KEY:-VtQwnrPU75cMIFFquIbZpiIyxFL0siqf}"
ETH="0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
PID="866a61811189692e8eccae5d2759724a812fa6f8703ebffe90c29dc1f886bbc1"

if [ "$ACTION" = "buy" ]; then
  INPUT="$ETH"
  OUTPUT="$TOKEN"
else
  INPUT="$TOKEN"
  OUTPUT="$ETH"
fi

# Step 1: Get quote with calldata
echo "Getting quote..."
QUOTE=$(curl -s -X POST "https://router.gluex.xyz/v1/quote" \
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
    \"activateSurplusFee\": false,
    \"surgeProtection\": false
  }")

echo "$QUOTE" | jq '{inputUSD: .result.inputAmountUSD, outputUSD: .result.outputAmountUSD, route: .result.liquidityModules}'

ROUTER=$(echo "$QUOTE" | jq -r '.result.router')
CALLDATA=$(echo "$QUOTE" | jq -r '.result.calldata')
VALUE=$(echo "$QUOTE" | jq -r '.result.value // "0"')

if [ -z "$CALLDATA" ] || [ "$CALLDATA" = "null" ]; then
  echo "ERROR: No calldata returned from quote"
  exit 1
fi

# Step 2: If selling a token, check and set approval first
if [ "$ACTION" = "sell" ]; then
  echo "Checking token approval..."
  ALLOWANCE=$(cast call "$TOKEN" "allowance(address,address)(uint256)" "$ADDRESS" "$ROUTER" --rpc-url "$RPC" 2>/dev/null || echo "0")

  if [ "$(echo "$ALLOWANCE" | tr -d '[:space:]')" = "0" ] || [ "$ALLOWANCE" -lt "$AMOUNT" ] 2>/dev/null; then
    echo "Approving token spend via server wallet..."
    APPROVE_DATA=$(cast calldata "approve(address,uint256)" "$ROUTER" "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
    APPROVE_RESULT=$(curl -s -X POST "${PLATFORM_API_URL}/api/v1/tx/send" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${PLATFORM_API_KEY}" \
      -d "{\"to\": \"$TOKEN\", \"data\": \"$APPROVE_DATA\"}")
    echo "$APPROVE_RESULT" | jq '{hash: .data.hash}'
    echo "Approval done."
  fi
fi

# Step 3: Send the swap transaction via server wallet
echo "Sending swap transaction..."
TX_RESULT=$(curl -s -X POST "${PLATFORM_API_URL}/api/v1/tx/send" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${PLATFORM_API_KEY}" \
  -d "{\"to\": \"$ROUTER\", \"value\": \"$VALUE\", \"data\": \"$CALLDATA\"}")

echo "$TX_RESULT" | jq '{hash: .data.hash}'

echo "Swap complete!"
