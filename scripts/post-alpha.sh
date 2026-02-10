#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ALPHA_TYPE="$1"
CONTENT="$2"

if [[ -z "$ALPHA_TYPE" || -z "$CONTENT" ]]; then
    echo "Usage: $0 <type> <content>" >&2
    echo "Types: market_insight, token_discovery, trend_alert" >&2
    exit 1
fi

echo "🐦 Formatting alpha tweet..." >&2

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

# Use new twitter-action.sh system
PARAMS_JSON=$(jq -n --arg text "$TWEET_TEXT" '{"text": $text}')
TWEET_INSTRUCTION=$("$(dirname "$0")/twitter-action.sh" "post" "$PARAMS_JSON")

# Add metadata for the agent
echo "$TWEET_INSTRUCTION" | jq \
    --arg alpha_type "$ALPHA_TYPE" \
    --arg content "$CONTENT" \
    '. + {
        alpha_type: $alpha_type,
        original_content: $content,
        instruction: "Agent should use browser tool to post this tweet to X/Twitter"
    }'