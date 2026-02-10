#!/bin/bash
# Universal Twitter action formatter for OpenClaw browser automation
# Outputs JSON instructions that the agent executes via browser tool
# Auto-reports the action to the Spirit platform if configured
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ACTION="$1"
PARAMS_JSON="${2:-{}}"

if [ -z "$ACTION" ]; then
    echo "Usage: twitter-action.sh <action> <params_json>" >&2
    echo "Actions: post, reply, quote, like, retweet, follow, unfollow, bookmark, delete" >&2
    exit 1
fi

# Validate action
case "$ACTION" in
    post|reply|quote|like|retweet|follow|unfollow|bookmark|delete)
        ;;
    *)
        echo "❌ Invalid action: $ACTION" >&2
        exit 1
        ;;
esac

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Parse and validate params based on action
case "$ACTION" in
    post)
        TEXT=$(echo "$PARAMS_JSON" | jq -r '.text // ""')
        if [ -z "$TEXT" ]; then echo "❌ Missing: text" >&2; exit 1; fi
        if [ ${#TEXT} -gt 280 ]; then TEXT="${TEXT:0:277}..."; fi
        OUTPUT=$(jq -n --arg action "$ACTION" --arg text "$TEXT" --arg ts "$TIMESTAMP" \
            '{action:"twitter_action",twitter_action:$action,text:$text,timestamp:$ts}')
        ;;
    reply|quote)
        TEXT=$(echo "$PARAMS_JSON" | jq -r '.text // ""')
        TWEET_ID=$(echo "$PARAMS_JSON" | jq -r '.tweet_id // ""')
        TWEET_URL=$(echo "$PARAMS_JSON" | jq -r '.tweet_url // ""')
        if [ -z "$TEXT" ]; then echo "❌ Missing: text" >&2; exit 1; fi
        if [ -z "$TWEET_ID" ] && [ -z "$TWEET_URL" ]; then echo "❌ Missing: tweet_id or tweet_url" >&2; exit 1; fi
        MAX=$([[ "$ACTION" == "quote" ]] && echo 240 || echo 280)
        if [ ${#TEXT} -gt $MAX ]; then TEXT="${TEXT:0:$((MAX-3))}..."; fi
        OUTPUT=$(jq -n --arg action "$ACTION" --arg text "$TEXT" --arg tid "$TWEET_ID" --arg turl "$TWEET_URL" --arg ts "$TIMESTAMP" \
            '{action:"twitter_action",twitter_action:$action,text:$text,tweet_id:$tid,tweet_url:$turl,timestamp:$ts}')
        ;;
    like|retweet|bookmark|delete)
        TWEET_ID=$(echo "$PARAMS_JSON" | jq -r '.tweet_id // ""')
        TWEET_URL=$(echo "$PARAMS_JSON" | jq -r '.tweet_url // ""')
        if [ -z "$TWEET_ID" ] && [ -z "$TWEET_URL" ]; then echo "❌ Missing: tweet_id or tweet_url" >&2; exit 1; fi
        OUTPUT=$(jq -n --arg action "$ACTION" --arg tid "$TWEET_ID" --arg turl "$TWEET_URL" --arg ts "$TIMESTAMP" \
            '{action:"twitter_action",twitter_action:$action,tweet_id:$tid,tweet_url:$turl,timestamp:$ts}')
        ;;
    follow|unfollow)
        USERNAME=$(echo "$PARAMS_JSON" | jq -r '.username // ""')
        USER_URL=$(echo "$PARAMS_JSON" | jq -r '.user_url // ""')
        if [ -z "$USERNAME" ] && [ -z "$USER_URL" ]; then echo "❌ Missing: username or user_url" >&2; exit 1; fi
        OUTPUT=$(jq -n --arg action "$ACTION" --arg user "$USERNAME" --arg uurl "$USER_URL" --arg ts "$TIMESTAMP" \
            '{action:"twitter_action",twitter_action:$action,username:$user,user_url:$uurl,timestamp:$ts}')
        ;;
esac

# Output instructions for the agent
echo "$OUTPUT"

# Auto-report to platform
if [[ -n "${PLATFORM_API_URL:-}" && -n "${PLATFORM_API_KEY:-}" ]]; then
    # Build social action payload
    TWEET_ID=$(echo "$PARAMS_JSON" | jq -r '.tweet_id // .external_id // empty' 2>/dev/null || true)
    TWEET_URL=$(echo "$PARAMS_JSON" | jq -r '.tweet_url // .external_url // empty' 2>/dev/null || true)
    TEXT=$(echo "$PARAMS_JSON" | jq -r '.text // .content // empty' 2>/dev/null || true)
    PARENT_ID=$(echo "$PARAMS_JSON" | jq -r '.tweet_id // empty' 2>/dev/null || true)

    # Map action names to social action types
    case "$ACTION" in
        post) ACTION_TYPE="tweet" ;;
        reply) ACTION_TYPE="reply" ;;
        quote) ACTION_TYPE="quote" ;;
        like) ACTION_TYPE="like" ;;
        retweet) ACTION_TYPE="retweet" ;;
        follow) ACTION_TYPE="follow" ;;
        unfollow) ACTION_TYPE="unfollow" ;;
        bookmark) ACTION_TYPE="bookmark" ;;
        delete) ACTION_TYPE="delete" ;;
        *) ACTION_TYPE="$ACTION" ;;
    esac

    SOCIAL_PAYLOAD=$(jq -n \
        --arg action_type "$ACTION_TYPE" \
        --arg external_id "${TWEET_ID:-}" \
        --arg external_url "${TWEET_URL:-}" \
        --arg content "${TEXT:-}" \
        --arg parent_external_id "$([[ "$ACTION" == "reply" || "$ACTION" == "quote" ]] && echo "${PARENT_ID:-}" || echo "")" \
        --arg posted_at "$TIMESTAMP" \
        '{
            platform: "x",
            action_type: $action_type,
            external_id: (if $external_id == "" then null else $external_id end),
            external_url: (if $external_url == "" then null else $external_url end),
            content: (if $content == "" then null else $content end),
            parent_external_id: (if $parent_external_id == "" then null else $parent_external_id end),
            posted_at: $posted_at,
            likes: 0, reposts: 0, replies: 0, impressions: 0
        }')

    # Fire and forget — don't block the agent
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $PLATFORM_API_KEY" \
        -d "$SOCIAL_PAYLOAD" \
        "$PLATFORM_API_URL/api/v1/social-actions" >/dev/null 2>&1 &
fi
