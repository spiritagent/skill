#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

# Check required vars
if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" || -z "${AGENT_ID:-}" ]]; then
    echo "❌ Missing required environment variables"
    echo "   PLATFORM_API_URL, PLATFORM_API_KEY, AGENT_ID"
    exit 1
fi

echo "Registering agent with platform..."

# Build socials array
SOCIALS=()
[[ -n "${TWITTER_USERNAME:-}" ]] && SOCIALS+=("twitter:$TWITTER_USERNAME")

# Convert array to JSON
SOCIALS_JSON="[]"
if [[ ${#SOCIALS[@]} -gt 0 ]]; then
    SOCIALS_JSON=$(printf '%s\n' "${SOCIALS[@]}" | jq -R . | jq -s .)
fi

# Registration payload
PAYLOAD=$(jq -n \
    --arg agentId "$AGENT_ID" \
    --arg wallet "$BASE_WALLET_ADDRESS" \
    --arg chain "base" \
    --argjson socials "$SOCIALS_JSON" \
    '{
        agentId: $agentId,
        wallet: $wallet,
        chain: $chain,
        socials: $socials,
        timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ")
    }'
)

# Register with platform
RESPONSE=$(curl -s -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$PAYLOAD" \
    "$PLATFORM_API_URL/api/agents/register" || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ Agent registered successfully"
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo "⚠️  Registration failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
    exit 1
fi