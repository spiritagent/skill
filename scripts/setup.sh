#!/bin/bash
set -euo pipefail

export PATH="$HOME/.foundry/bin:$PATH"

ENV_FILE="$(dirname "$0")/../.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Detect headless mode (--headless flag or HEADLESS=1 env)
HEADLESS=0
for arg in "$@"; do
    [[ "$arg" == "--headless" ]] && HEADLESS=1
done
[[ "${HEADLESS_MODE:-}" == "1" ]] && HEADLESS=1

prompt() {
    local var="$1" msg="$2" default="${3:-}"
    if [[ $HEADLESS -eq 1 ]]; then
        # In headless mode, use env var or default
        eval "REPLY=\${$var:-$default}"
    else
        read -p "$msg" REPLY
        REPLY="${REPLY:-$default}"
    fi
    echo "$REPLY"
}

echo "🚀 Spirit Agent Setup" >&2
echo "=====================" >&2
[[ $HEADLESS -eq 1 ]] && echo "Running in headless mode" >&2
echo >&2

# --- Auto-install deps ---
if ! command -v jq >/dev/null 2>&1; then
    echo "📦 Installing jq..." >&2
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq jq 2>/dev/null
    elif command -v brew >/dev/null 2>&1; then
        brew install jq 2>/dev/null
    fi
fi
command -v jq >/dev/null 2>&1 && echo "✅ jq" >&2 || { echo "❌ jq required" >&2; exit 1; }

if ! command -v cast >/dev/null 2>&1; then
    echo "📦 Installing Foundry..." >&2
    curl -sL https://foundry.paradigm.xyz | bash 2>/dev/null
    export PATH="$HOME/.foundry/bin:$PATH"
    foundryup 2>/dev/null
fi
command -v cast >/dev/null 2>&1 && echo "✅ foundry" >&2 || { echo "❌ foundry required" >&2; exit 1; }

# --- 1. Platform API key ---
echo >&2
PLATFORM_API_URL="${PLATFORM_API_URL:-https://api.spiritagent.fun}"
PLATFORM_API_KEY="${PLATFORM_API_KEY:-}"

if [[ -z "$PLATFORM_API_KEY" ]]; then
    if [[ $HEADLESS -eq 1 ]]; then
        echo "❌ PLATFORM_API_KEY is required in headless mode" >&2
        exit 1
    fi
    read -p "🔑 Platform API key: " PLATFORM_API_KEY
fi
echo "✅ API key set" >&2

# --- 2. Agent config ---
AGENT_ID="${AGENT_ID:-}"
STRATEGY="${STRATEGY:-default}"

if [[ -z "$AGENT_ID" ]]; then
    if [[ $HEADLESS -eq 1 ]]; then
        AGENT_ID="agent-$(head -c 4 /dev/urandom | xxd -p)"
        echo "Auto-generated agent ID: $AGENT_ID" >&2
    else
        read -p "🤖 Agent name: " AGENT_ID
        echo "Strategies: default (conservative), degen (aggressive)" >&2
        read -p "Strategy [default]: " STRATEGY
        STRATEGY="${STRATEGY:-default}"
    fi
fi
echo "✅ Agent: $AGENT_ID ($STRATEGY)" >&2

# --- 3. Write .env ---
echo >&2
echo "Writing .env..." >&2
cat > "$ENV_FILE" << EOF
# Spirit Agent Configuration
PLATFORM_API_URL="$PLATFORM_API_URL"
PLATFORM_API_KEY="$PLATFORM_API_KEY"
AGENT_ID="$AGENT_ID"
STRATEGY="$STRATEGY"
GLUEX_API_KEY="VtQwnrPU75cMIFFquIbZpiIyxFL0siqf"
BASE_RPC="https://mainnet.base.org"

# Set by platform on registration
BASE_WALLET_ADDRESS=""

# Twitter (optional)
TWITTER_USERNAME=""
TWITTER_AUTH_TOKEN=""
TWITTER_CT0=""

export PATH="\$HOME/.foundry/bin:\$PATH"
EOF
echo "✅ .env saved" >&2

# --- 4. Get API key from onboard/token ---
echo >&2
echo "🔑 Getting agent API key..." >&2
source "$ENV_FILE"

ONBOARD_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg name "$AGENT_ID" --arg strategy "$STRATEGY" '{name: $name, metadata: {strategy: $strategy}}')" \
    "$PLATFORM_API_URL/api/v1/onboard/token" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$ONBOARD_RESPONSE" | tail -1)
ONBOARD_BODY=$(echo "$ONBOARD_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    AGENT_API_KEY=$(echo "$ONBOARD_BODY" | jq -r '.data.apiKey // empty' 2>/dev/null)
    WALLET=$(echo "$ONBOARD_BODY" | jq -r '.data.walletAddress // empty' 2>/dev/null)
    
    if [[ -n "$AGENT_API_KEY" ]]; then
        # Update .env with the actual agent API key
        sed -i.bak "s/^PLATFORM_API_KEY=\".*\"/PLATFORM_API_KEY=\"$AGENT_API_KEY\"/" "$ENV_FILE"
        
        if [[ -n "$WALLET" ]]; then
            sed -i.bak "s/^BASE_WALLET_ADDRESS=\"\"/BASE_WALLET_ADDRESS=\"$WALLET\"/" "$ENV_FILE"
            echo "✅ Onboarded! Wallet: $WALLET" >&2
        else
            echo "✅ Onboarded!" >&2
        fi
        rm -f "$ENV_FILE.bak"
        
        # Extract API key prefix for Twitter pairing
        API_KEY_PREFIX="${AGENT_API_KEY:0:16}"
        echo "   API Key Prefix: $API_KEY_PREFIX" >&2
    else
        echo "❌ Onboard failed - no API key returned" >&2
        exit 1
    fi
else
    echo "❌ Onboard failed (HTTP $HTTP_CODE)" >&2
    echo "$ONBOARD_BODY" >&2
    exit 1
fi

# --- 5. Twitter pairing (interactive only) ---
if [[ $HEADLESS -eq 0 ]]; then
    echo >&2
    read -p "🐦 Connect Twitter? (y/N): " connect_twitter
    if [[ "$connect_twitter" =~ ^[Yy] ]]; then
        read -p "Twitter @username: " TW_USER
        if [[ -n "$TW_USER" ]]; then
            sed -i.bak "s/^TWITTER_USERNAME=\"\"/TWITTER_USERNAME=\"$TW_USER\"/" "$ENV_FILE"
            rm -f "$ENV_FILE.bak"
            
            echo >&2
            echo "📱 Twitter Pairing Instructions:" >&2
            echo "=================================" >&2
            echo "1. Post this tweet from your account (@$TW_USER):" >&2
            echo >&2
            echo "🤖 Activating my Spirit Agent! Pairing code: $API_KEY_PREFIX" >&2
            echo >&2
            echo "@spiritdottown" >&2
            echo >&2
            echo "2. After posting, copy the tweet ID from the URL" >&2
            echo "   Example: https://x.com/$TW_USER/status/1234567890 → tweet ID is 1234567890" >&2
            echo >&2
            echo "3. Then run: ./scripts/register.sh @$TW_USER <tweet_id>" >&2
            echo >&2
            read -p "Press Enter to continue..."
        fi
    fi
fi

# --- 6. Done ---
echo >&2
echo "🎉 Setup complete!" >&2
echo >&2
echo "Your agent '$AGENT_ID' is ready." >&2
echo "Wallet: ${WALLET:-pending registration}" >&2
echo "Strategy: $STRATEGY" >&2
echo >&2
echo "Now send this to your OpenClaw agent:" >&2
echo >&2
echo "  I just installed spirit-agent. Start the trading agent loop with strategy '$STRATEGY'." >&2
echo >&2
