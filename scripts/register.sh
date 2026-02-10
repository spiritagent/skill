#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

# Check required vars
if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "❌ Missing required environment variables"
    echo "   PLATFORM_API_URL, PLATFORM_API_KEY"
    exit 1
fi

X_USERNAME="$1"
TWEET_ID="$2"

if [[ -z "$X_USERNAME" ]] || [[ -z "$TWEET_ID" ]]; then
    echo "❌ Usage: $0 <@username> <tweet_id>"
    echo ""
    echo "📝 To complete registration:"
    echo "1. Get your API key prefix from your .env file"
    echo "2. Post a tweet like this:"
    echo ""
    echo "🤖 Activating my Spirit Agent! Pairing code: [YOUR_API_KEY_PREFIX]"
    echo ""
    echo "@spiritdotfun"
    echo ""
    echo "3. Copy the tweet ID from the URL and run:"
    echo "   $0 @yourusername 1234567890"
    exit 1
fi

# Extract API key prefix for display
API_KEY_PREFIX=""
if [[ -n "${PLATFORM_API_KEY:-}" ]]; then
    API_KEY_PREFIX="${PLATFORM_API_KEY:0:16}..."
fi

echo "📱 Registering agent with Twitter pairing..."
echo "   Username: $X_USERNAME"
echo "   Tweet ID: $TWEET_ID"
echo "   API Key Prefix: $API_KEY_PREFIX"
echo ""

# Registration payload
PAYLOAD=$(jq -n \
    --arg x_username "$X_USERNAME" \
    --arg tweet_id "$TWEET_ID" \
    '{
        x_username: $x_username,
        tweet_id: $tweet_id
    }'
)

# Register with platform
RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$PAYLOAD" \
    "$PLATFORM_API_URL/api/v1/agents/register" 2>/dev/null || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ Agent registered successfully with Twitter!"
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo "❌ Registration failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
    
    if [[ "$HTTP_CODE" == "400" ]]; then
        echo ""
        echo "💡 Common issues:"
        echo "   - Make sure your tweet contains your API key prefix: $API_KEY_PREFIX"
        echo "   - Verify the tweet ID is correct"
        echo "   - Check that the username matches the tweet author"
    fi
    
    exit 1
fi