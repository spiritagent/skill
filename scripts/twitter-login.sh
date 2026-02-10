#!/bin/bash
# Twitter/X Login via OpenClaw Browser
# Opens x.com in the openclaw browser profile for manual login.
# Cookies persist in the profile — only need to do this once.
# Fallback: user can paste cookies directly if browser login fails.
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

PROFILE="${OPENCLAW_BROWSER_PROFILE:-openclaw}"
ENV_FILE="$(dirname "$0")/../.env"

echo "🐦 Opening X/Twitter login in OpenClaw browser..."
echo "   Profile: $PROFILE"
echo

# Try browser login first
openclaw browser open "https://x.com/i/flow/login" --browser-profile "$PROFILE" --target host 2>/dev/null || {
    echo "⚠️  Could not open OpenClaw browser."
    echo
    # Jump straight to cookie fallback
    echo "You can paste your cookies instead."
    echo "Get them from your browser DevTools → Application → Cookies → x.com"
    echo
    read -p "auth_token: " MANUAL_AUTH
    read -p "ct0: " MANUAL_CT0

    if [ -n "$MANUAL_AUTH" ] && [ -n "$MANUAL_CT0" ]; then
        # Append to .env
        if grep -q "^TWITTER_AUTH_TOKEN=" "$ENV_FILE" 2>/dev/null; then
            sed -i.bak "s/^TWITTER_AUTH_TOKEN=.*/TWITTER_AUTH_TOKEN=\"$MANUAL_AUTH\"/" "$ENV_FILE"
            sed -i.bak "s/^TWITTER_CT0=.*/TWITTER_CT0=\"$MANUAL_CT0\"/" "$ENV_FILE"
            rm -f "$ENV_FILE.bak"
        else
            echo "" >> "$ENV_FILE"
            echo "# Twitter cookies (manual)" >> "$ENV_FILE"
            echo "TWITTER_AUTH_TOKEN=\"$MANUAL_AUTH\"" >> "$ENV_FILE"
            echo "TWITTER_CT0=\"$MANUAL_CT0\"" >> "$ENV_FILE"
        fi
        echo "✅ Twitter cookies saved to .env"
        exit 0
    else
        echo "❌ Both auth_token and ct0 are required."
        exit 1
    fi
}

echo
echo "👆 Please log in manually in the browser window."
echo "   Once logged in, your session will persist in the '$PROFILE' profile."
echo
echo "Waiting for login to complete..."

# Poll until we detect auth cookies
for i in $(seq 1 60); do
    sleep 3
    COOKIES=$(openclaw browser cookies --json --browser-profile "$PROFILE" 2>/dev/null || echo "[]")
    AUTH=$(echo "$COOKIES" | jq -r '.[] | select(.name=="auth_token") | .value // empty' 2>/dev/null || true)

    if [ -n "$AUTH" ]; then
        USERNAME=$(echo "$COOKIES" | jq -r '.[] | select(.name=="twid") | .value // empty' 2>/dev/null | sed 's/u%3D//')
        echo
        echo "✅ Twitter login detected!"
        [ -n "$USERNAME" ] && echo "   User ID: $USERNAME"
        echo "   Session saved in '$PROFILE' profile."
        exit 0
    fi
done

# Browser login timed out — offer cookie fallback
echo
echo "⚠️  Timed out waiting for login."
echo "   You can paste your cookies manually instead."
echo "   Get them from your browser DevTools → Application → Cookies → x.com"
echo
read -p "auth_token (or Enter to skip): " MANUAL_AUTH

if [ -n "$MANUAL_AUTH" ]; then
    read -p "ct0: " MANUAL_CT0

    if [ -n "$MANUAL_CT0" ]; then
        if grep -q "^TWITTER_AUTH_TOKEN=" "$ENV_FILE" 2>/dev/null; then
            sed -i.bak "s/^TWITTER_AUTH_TOKEN=.*/TWITTER_AUTH_TOKEN=\"$MANUAL_AUTH\"/" "$ENV_FILE"
            sed -i.bak "s/^TWITTER_CT0=.*/TWITTER_CT0=\"$MANUAL_CT0\"/" "$ENV_FILE"
            rm -f "$ENV_FILE.bak"
        else
            echo "" >> "$ENV_FILE"
            echo "# Twitter cookies (manual)" >> "$ENV_FILE"
            echo "TWITTER_AUTH_TOKEN=\"$MANUAL_AUTH\"" >> "$ENV_FILE"
            echo "TWITTER_CT0=\"$MANUAL_CT0\"" >> "$ENV_FILE"
        fi
        echo "✅ Twitter cookies saved to .env"
        exit 0
    fi
fi

echo "⚠️  Skipping Twitter. You can retry later with: ./scripts/twitter-login.sh"
exit 1
