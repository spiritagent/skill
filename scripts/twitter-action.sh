#!/bin/bash
# Universal Twitter action formatter for OpenClaw browser automation
# Outputs JSON instructions that the agent executes via browser tool
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

ACTION="$1"
PARAMS_JSON="${2:-{}}"

if [ -z "$ACTION" ]; then
    echo "Usage: twitter-action.sh <action> <params_json>" >&2
    echo "Actions: post, reply, quote, like, retweet, follow, unfollow, bookmark" >&2
    exit 1
fi

# Validate action
case "$ACTION" in
    post|reply|quote|like|retweet|follow|unfollow|bookmark)
        ;;
    *)
        echo "❌ Invalid action: $ACTION" >&2
        echo "Valid actions: post, reply, quote, like, retweet, follow, unfollow, bookmark" >&2
        exit 1
        ;;
esac

# Parse and validate params based on action
case "$ACTION" in
    post)
        TEXT=$(echo "$PARAMS_JSON" | jq -r '.text // ""')
        if [ -z "$TEXT" ]; then
            echo "❌ Missing required parameter: text" >&2
            exit 1
        fi
        # Truncate to 280 chars
        if [ ${#TEXT} -gt 280 ]; then
            TEXT="${TEXT:0:277}..."
        fi
        OUTPUT=$(jq -n \
            --arg action "$ACTION" \
            --arg text "$TEXT" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                action: "twitter_action",
                twitter_action: $action,
                text: $text,
                timestamp: $timestamp
            }')
        ;;
    
    reply)
        TEXT=$(echo "$PARAMS_JSON" | jq -r '.text // ""')
        TWEET_ID=$(echo "$PARAMS_JSON" | jq -r '.tweet_id // ""')
        TWEET_URL=$(echo "$PARAMS_JSON" | jq -r '.tweet_url // ""')
        
        if [ -z "$TEXT" ]; then
            echo "❌ Missing required parameter: text" >&2
            exit 1
        fi
        if [ -z "$TWEET_ID" ] && [ -z "$TWEET_URL" ]; then
            echo "❌ Missing required parameter: tweet_id or tweet_url" >&2
            exit 1
        fi
        
        # Truncate to 280 chars
        if [ ${#TEXT} -gt 280 ]; then
            TEXT="${TEXT:0:277}..."
        fi
        
        OUTPUT=$(jq -n \
            --arg action "$ACTION" \
            --arg text "$TEXT" \
            --arg tweet_id "$TWEET_ID" \
            --arg tweet_url "$TWEET_URL" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                action: "twitter_action",
                twitter_action: $action,
                text: $text,
                tweet_id: $tweet_id,
                tweet_url: $tweet_url,
                timestamp: $timestamp
            }')
        ;;
    
    quote)
        TEXT=$(echo "$PARAMS_JSON" | jq -r '.text // ""')
        TWEET_ID=$(echo "$PARAMS_JSON" | jq -r '.tweet_id // ""')
        TWEET_URL=$(echo "$PARAMS_JSON" | jq -r '.tweet_url // ""')
        
        if [ -z "$TEXT" ]; then
            echo "❌ Missing required parameter: text" >&2
            exit 1
        fi
        if [ -z "$TWEET_ID" ] && [ -z "$TWEET_URL" ]; then
            echo "❌ Missing required parameter: tweet_id or tweet_url" >&2
            exit 1
        fi
        
        # Truncate to 280 chars (minus space for quoted tweet)
        if [ ${#TEXT} -gt 240 ]; then
            TEXT="${TEXT:0:237}..."
        fi
        
        OUTPUT=$(jq -n \
            --arg action "$ACTION" \
            --arg text "$TEXT" \
            --arg tweet_id "$TWEET_ID" \
            --arg tweet_url "$TWEET_URL" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                action: "twitter_action",
                twitter_action: $action,
                text: $text,
                tweet_id: $tweet_id,
                tweet_url: $tweet_url,
                timestamp: $timestamp
            }')
        ;;
    
    like|retweet|bookmark)
        TWEET_ID=$(echo "$PARAMS_JSON" | jq -r '.tweet_id // ""')
        TWEET_URL=$(echo "$PARAMS_JSON" | jq -r '.tweet_url // ""')
        
        if [ -z "$TWEET_ID" ] && [ -z "$TWEET_URL" ]; then
            echo "❌ Missing required parameter: tweet_id or tweet_url" >&2
            exit 1
        fi
        
        OUTPUT=$(jq -n \
            --arg action "$ACTION" \
            --arg tweet_id "$TWEET_ID" \
            --arg tweet_url "$TWEET_URL" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                action: "twitter_action",
                twitter_action: $action,
                tweet_id: $tweet_id,
                tweet_url: $tweet_url,
                timestamp: $timestamp
            }')
        ;;
    
    follow|unfollow)
        USERNAME=$(echo "$PARAMS_JSON" | jq -r '.username // ""')
        USER_URL=$(echo "$PARAMS_JSON" | jq -r '.user_url // ""')
        
        if [ -z "$USERNAME" ] && [ -z "$USER_URL" ]; then
            echo "❌ Missing required parameter: username or user_url" >&2
            exit 1
        fi
        
        OUTPUT=$(jq -n \
            --arg action "$ACTION" \
            --arg username "$USERNAME" \
            --arg user_url "$USER_URL" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                action: "twitter_action",
                twitter_action: $action,
                username: $username,
                user_url: $user_url,
                timestamp: $timestamp
            }')
        ;;
esac

echo "$OUTPUT"