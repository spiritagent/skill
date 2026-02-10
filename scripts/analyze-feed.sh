#!/bin/bash
# Analyze Twitter/X feed text for trading signals
# Usage: analyze-feed.sh [snapshot_file]
# If no file given, reads from stdin
# Extracts trading signals from Twitter feed text
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

echo "🐦 Analyzing X feed for alpha..." >&2

# Read input from file or stdin
if [ $# -gt 0 ] && [ -f "$1" ]; then
    FEED_TEXT=$(cat "$1")
    echo "📄 Reading from file: $1" >&2
else
    echo "📖 Reading from stdin..." >&2
    FEED_TEXT=$(cat)
fi

if [ -z "$FEED_TEXT" ]; then
    echo "⚠️  No feed text provided" >&2
    jq -n '{
        status: "no_input",
        signals: [],
        trending: { tokens: [], hashtags: [] },
        sentiment: { overall: "unknown", confidence: 0 },
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'
    exit 0
fi

# Extract token mentions ($TICKER patterns) - case insensitive with token counts
TOKENS_RAW=$(echo "$FEED_TEXT" | grep -ioE '\$[A-Z]{2,10}' | tr '[:lower:]' '[:upper:]' | sort | uniq -c | sort -rn | head -15)

# Extract hashtags - case preserving with counts
HASHTAGS_RAW=$(echo "$FEED_TEXT" | grep -oE '#[A-Za-z0-9_]+' | sort | uniq -c | sort -rn | head -15)

# Convert to JSON arrays with counts
TOKENS=$(echo "$TOKENS_RAW" | awk '{print "{\"symbol\":\"" $2 "\",\"mentions\":" $1 "}"}' 2>/dev/null | jq -s '.' || echo '[]')
HASHTAGS=$(echo "$HASHTAGS_RAW" | awk '{print "{\"tag\":\"" $2 "\",\"mentions\":" $1 "}"}' 2>/dev/null | jq -s '.' || echo '[]')

# Sentiment analysis: count bullish vs bearish keywords
BULLISH=$(echo "$FEED_TEXT" | grep -ciE '\b(bull|bullish|pump|moon|buy|long|breakout|ath|gem|rocket|send it|wagmi|diamond|hold|hodl|up only|to the moon|lets go|launch|fly|parabolic)\b' || echo 0)
BEARISH=$(echo "$FEED_TEXT" | grep -ciE '\b(bear|bearish|dump|short|sell|crash|rug|scam|rekt|ngmi|dead|down|fall|drop|panic|fear|avoid|trap|bubble)\b' || echo 0)
TOTAL=$((BULLISH + BEARISH))

# Calculate sentiment
if [ "$TOTAL" -gt 0 ]; then
    if [ "$BULLISH" -gt "$BEARISH" ]; then
        SENTIMENT="bullish"
        CONFIDENCE=$(awk -v b="$BULLISH" -v t="$TOTAL" 'BEGIN {printf "%.2f", b/t}')
    else
        SENTIMENT="bearish" 
        CONFIDENCE=$(awk -v b="$BEARISH" -v t="$TOTAL" 'BEGIN {printf "%.2f", b/t}')
    fi
else
    SENTIMENT="neutral"
    CONFIDENCE="0.00"
fi

# Extract potential alpha signals (mentions with high engagement indicators)
ALPHA_SIGNALS=$(echo "$FEED_TEXT" | grep -E '(🔥|🚀|💎|⬆️|📈)|\b(alpha|call|gem|early|hidden|sleeper|moonshot|100x|1000x)\b' | head -5 || echo "")

# Count signals
SIGNAL_COUNT=$(echo "$ALPHA_SIGNALS" | wc -l)
if [ -z "$ALPHA_SIGNALS" ] || [ "$ALPHA_SIGNALS" = " " ]; then
    SIGNAL_COUNT=0
fi

# Output structured analysis
jq -n \
    --argjson tokens "$TOKENS" \
    --argjson hashtags "$HASHTAGS" \
    --arg sentiment "$SENTIMENT" \
    --argjson confidence "$CONFIDENCE" \
    --argjson bullish "$BULLISH" \
    --argjson bearish "$BEARISH" \
    --argjson signal_count "$SIGNAL_COUNT" \
    '{
        status: "ok",
        trending: {
            tokens: $tokens,
            hashtags: $hashtags
        },
        sentiment: {
            overall: $sentiment,
            confidence: $confidence,
            bullish_signals: $bullish,
            bearish_signals: $bearish
        },
        alpha_signals: $signal_count,
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'