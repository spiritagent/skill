#!/bin/bash
# Analyze X/Twitter feed for trading signals using OpenClaw browser
# Reads the logged-in user's timeline and extracts token mentions, sentiment, trends
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

PROFILE="${OPENCLAW_BROWSER_PROFILE:-openclaw}"

echo "🐦 Analyzing X feed for alpha..." >&2

# Try OpenClaw browser cookies first, fallback to .env
COOKIES=$(openclaw browser cookies --json --browser-profile "$PROFILE" 2>/dev/null || echo "[]")
AUTH=$(echo "$COOKIES" | jq -r '.[] | select(.name=="auth_token") | .value // empty' 2>/dev/null || true)
[ -z "$AUTH" ] && AUTH="${TWITTER_AUTH_TOKEN:-}"

if [ -z "$AUTH" ]; then
    echo "⚠️  No active Twitter session. Run ./scripts/twitter-login.sh first." >&2
    jq -n '{
        status: "no_session",
        signals: [],
        trending: { tokens: [], hashtags: [] },
        sentiment: { overall: "unknown", confidence: 0 },
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'
    exit 0
fi

# Navigate to the feed
openclaw browser open "https://x.com/home" --browser-profile "$PROFILE" --target host >/dev/null 2>&1
openclaw browser wait --load networkidle --timeout-ms 10000 --browser-profile "$PROFILE" >/dev/null 2>&1 || true
sleep 2

# Take a snapshot of the timeline
SNAPSHOT=$(openclaw browser snapshot --browser-profile "$PROFILE" 2>/dev/null || echo "")

if [ -z "$SNAPSHOT" ]; then
    echo "⚠️  Could not read feed" >&2
    jq -n '{
        status: "error",
        signals: [],
        trending: { tokens: [], hashtags: [] },
        sentiment: { overall: "unknown", confidence: 0 },
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'
    exit 0
fi

# Extract token mentions ($TICKER patterns) and hashtags
TOKENS=$(echo "$SNAPSHOT" | grep -oE '\$[A-Z]{2,10}' | sort | uniq -c | sort -rn | head -10 | awk '{print $2}' | jq -R . | jq -s .)
HASHTAGS=$(echo "$SNAPSHOT" | grep -oE '#[A-Za-z0-9_]+' | sort | uniq -c | sort -rn | head -10 | awk '{print $2}' | jq -R . | jq -s .)

# Basic sentiment: count bullish vs bearish keywords
BULLISH=$(echo "$SNAPSHOT" | grep -ciE 'bull|pump|moon|buy|long|breakout|ath|gem|rocket|send it|wagmi' || echo 0)
BEARISH=$(echo "$SNAPSHOT" | grep -ciE 'bear|dump|short|sell|crash|rug|scam|rekt|ngmi' || echo 0)
TOTAL=$((BULLISH + BEARISH))

if [ "$TOTAL" -gt 0 ]; then
    if [ "$BULLISH" -gt "$BEARISH" ]; then
        SENTIMENT="bullish"
        CONFIDENCE=$(echo "scale=2; $BULLISH / $TOTAL" | bc)
    else
        SENTIMENT="bearish"
        CONFIDENCE=$(echo "scale=2; $BEARISH / $TOTAL" | bc)
    fi
else
    SENTIMENT="neutral"
    CONFIDENCE="0"
fi

# Output structured analysis
jq -n \
    --argjson tokens "$TOKENS" \
    --argjson hashtags "$HASHTAGS" \
    --arg sentiment "$SENTIMENT" \
    --arg confidence "$CONFIDENCE" \
    --arg bullish "$BULLISH" \
    --arg bearish "$BEARISH" \
    '{
        status: "ok",
        trending: { tokens: $tokens, hashtags: $hashtags },
        sentiment: {
            overall: $sentiment,
            confidence: ($confidence | tonumber),
            bullish_signals: ($bullish | tonumber),
            bearish_signals: ($bearish | tonumber)
        },
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'
