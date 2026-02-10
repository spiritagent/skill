#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../.env"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "❌ Missing PLATFORM_API_URL or PLATFORM_API_KEY"
    exit 1
fi

X_USERNAME="${1:-}"
TWEET_ID="${2:-}"
PAIRING_CODE="${PAIRING_CODE:-}"

if [[ -z "$X_USERNAME" || -z "$TWEET_ID" ]]; then
    echo "Usage: $0 <@username> <tweet_id>"
    echo ""
    echo "The tweet must contain your pairing code: ${PAIRING_CODE:-<check setup output>}"
    exit 1
fi

echo "📱 Registering @${X_USERNAME#@} with tweet $TWEET_ID..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$(jq -n --arg u "$X_USERNAME" --arg t "$TWEET_ID" '{x_username:$u,tweet_id:$t}')" \
    "$PLATFORM_API_URL/api/v1/agents/register" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ Paired!"
    echo "$BODY" | jq -r '.data.message // "Success"' 2>/dev/null

    echo "✅ Pairing tweet kept on timeline"
else
    echo "❌ Failed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    exit 1
fi
