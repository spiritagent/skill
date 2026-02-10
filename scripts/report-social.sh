#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

SOCIAL_DATA="$1"

if [[ -z "$SOCIAL_DATA" ]]; then
    echo "Usage: $0 '<social_action_json>'"
    echo "Expected format: {\"action_type\": \"post\", \"external_id\": \"123\", \"content\": \"Hello\", \"posted_at\": \"2024-01-01T00:00:00Z\"}"
    echo "Action types: post, reply, like, retweet, quote, follow"
    exit 1
fi

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured, skipping social action report"
    exit 0
fi

echo "📱 Reporting social action to platform..."

# Build social action payload with required fields
SOCIAL_PAYLOAD=$(echo "$SOCIAL_DATA" | jq \
    '. + {
        platform: "x",
        action_type: .action_type,
        external_id: (.external_id // null),
        external_url: (.external_url // null),
        content: (.content // null),
        parent_external_id: (.parent_external_id // null),
        likes: (.likes // 0),
        reposts: (.reposts // 0),
        replies: (.replies // 0),
        impressions: (.impressions // 0),
        posted_at: .posted_at
    }'
)

# Send social action
RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$SOCIAL_PAYLOAD" \
    "$PLATFORM_API_URL/api/v1/social-actions" 2>/dev/null || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ Social action reported successfully"
    if [[ -n "$RESPONSE_BODY" ]]; then
        echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    fi
else
    echo "⚠️  Social action report failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
fi