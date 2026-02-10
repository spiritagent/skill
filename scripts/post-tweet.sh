#!/bin/bash
# Post a tweet via X's GraphQL API
# Usage: post-tweet.sh "<tweet text>"
# Cookie sources (checked in order):
#   1. OpenClaw browser profile (preferred)
#   2. TWITTER_AUTH_TOKEN + TWITTER_CT0 in .env (fallback)
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

TWEET_TEXT="$1"
PROFILE="${OPENCLAW_BROWSER_PROFILE:-openclaw}"

if [ -z "$TWEET_TEXT" ]; then
    echo "Usage: post-tweet.sh '<tweet text>'"
    exit 1
fi

# Try OpenClaw browser cookies first
AUTH=""
CT0=""
COOKIES=$(openclaw browser cookies --json --browser-profile "$PROFILE" 2>/dev/null || echo "[]")
AUTH=$(echo "$COOKIES" | jq -r '.[] | select(.name=="auth_token") | .value // empty' 2>/dev/null || true)
CT0=$(echo "$COOKIES" | jq -r '.[] | select(.name=="ct0") | .value // empty' 2>/dev/null || true)

# Fallback to .env cookies
if [ -z "$AUTH" ] || [ -z "$CT0" ]; then
    AUTH="${TWITTER_AUTH_TOKEN:-}"
    CT0="${TWITTER_CT0:-}"
fi

if [ -z "$AUTH" ] || [ -z "$CT0" ]; then
    echo "❌ No Twitter session found. Run ./scripts/twitter-login.sh first."
    exit 1
fi

echo "🐦 Posting tweet via OpenClaw browser..."

# Use Twitter's internal GraphQL API with cookies from the browser session
# This is more reliable than UI automation and doesn't require snapshot parsing
BEARER="AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

RESPONSE=$(curl -s -X POST "https://x.com/i/api/graphql/a1p9RWpkYKBjWv_I3WzS-A/CreateTweet" \
    -H "authorization: Bearer $BEARER" \
    -H "cookie: auth_token=$AUTH; ct0=$CT0" \
    -H "x-csrf-token: $CT0" \
    -H "content-type: application/json" \
    -H "x-twitter-active-user: yes" \
    -H "x-twitter-auth-type: OAuth2Session" \
    -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -d "$(jq -n --arg text "$TWEET_TEXT" '{
        variables: {
            tweet_text: $text,
            dark_request: false,
            media: { media_entities: [], possibly_sensitive: false },
            semantic_annotation_ids: []
        },
        features: {
            communities_web_enable_tweet_community_results_fetch: true,
            c9s_tweet_anatomy_moderator_badge_enabled: true,
            tweetypie_unmention_optimization_enabled: true,
            responsive_web_edit_tweet_api_enabled: true,
            graphql_is_translatable_rweb_tweet_is_translatable_enabled: true,
            view_counts_everywhere_api_enabled: true,
            longform_notetweets_consumption_enabled: true,
            responsive_web_twitter_article_tweet_consumption_enabled: true,
            tweet_awards_web_tipping_enabled: false,
            creator_subscriptions_quote_tweet_preview_enabled: false,
            longform_notetweets_rich_text_read_enabled: true,
            longform_notetweets_inline_media_enabled: true,
            articles_preview_enabled: true,
            rweb_video_timestamps_enabled: true,
            rweb_tipjar_consumption_enabled: true,
            responsive_web_graphql_exclude_directive_enabled: true,
            verified_phone_label_enabled: false,
            freedom_of_speech_not_reach_fetch_enabled: true,
            standardized_nudges_misinfo: true,
            tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: true,
            responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
            responsive_web_graphql_timeline_navigation_enabled: true,
            responsive_web_enhance_cards_enabled: false
        },
        queryId: "a1p9RWpkYKBjWv_I3WzS-A"
    }')")

# Parse response
TWEET_ID=$(echo "$RESPONSE" | jq -r '.data.create_tweet.tweet_results.result.rest_id // empty' 2>/dev/null || true)

if [ -n "$TWEET_ID" ]; then
    TWEET_URL="https://x.com/i/status/$TWEET_ID"
    echo "✅ Tweet posted: $TWEET_URL"
    jq -n \
        --arg url "$TWEET_URL" \
        --arg id "$TWEET_ID" \
        --arg content "$TWEET_TEXT" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{ success: true, tweet_url: $url, tweet_id: $id, content: $content, timestamp: $timestamp }'
else
    ERROR=$(echo "$RESPONSE" | jq -r '.errors[0].message // empty' 2>/dev/null || true)
    echo "❌ Tweet failed: ${ERROR:-unknown error}"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    exit 1
fi
