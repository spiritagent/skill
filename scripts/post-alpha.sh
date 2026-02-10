#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ALPHA_TYPE="$1"
CONTENT="$2"

if [[ -z "$ALPHA_TYPE" || -z "$CONTENT" ]]; then
    echo "Usage: $0 <type> <content>"
    echo "Types: market_insight, token_discovery, trend_alert"
    exit 1
fi

case "$ALPHA_TYPE" in
    "market_insight")  EMOJI="🧠"; PREFIX="Market Insight"; HASHTAGS="#MarketAnalysis #Base #DeFi" ;;
    "token_discovery") EMOJI="🔍"; PREFIX="Token Discovery"; HASHTAGS="#NewToken #Base #Gems" ;;
    "trend_alert")     EMOJI="📊"; PREFIX="Trend Alert";     HASHTAGS="#Trending #Base #Alpha" ;;
    *)                 EMOJI="💡"; PREFIX="Alpha";            HASHTAGS="#Alpha #Base #Crypto" ;;
esac

TWEET_TEXT="$EMOJI $PREFIX:

$CONTENT

$HASHTAGS"

# Truncate if too long
if [[ ${#TWEET_TEXT} -gt 280 ]]; then
    MAX_CONTENT_LENGTH=$((280 - ${#EMOJI} - ${#PREFIX} - ${#HASHTAGS} - 10))
    TRUNCATED_CONTENT="${CONTENT:0:$MAX_CONTENT_LENGTH}..."
    TWEET_TEXT="$EMOJI $PREFIX: $TRUNCATED_CONTENT

$HASHTAGS"
fi

echo "🐦 Posting alpha to X..."

# Post via OpenClaw browser
RESULT=$("$(dirname "$0")/post-tweet.sh" "$TWEET_TEXT")
echo "$RESULT"

# Report to platform
if [[ -n "${PLATFORM_API_KEY:-}" ]]; then
    "$(dirname "$0")/report-tweet.sh" "$RESULT"
fi
