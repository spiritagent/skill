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
PLATFORM_API_URL="${PLATFORM_API_URL:-https://spirit.town}"
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

# --- 4. Verify API key with platform ---
echo >&2
source "$ENV_FILE"

if [[ "$PLATFORM_API_KEY" == spirit_sk_* ]]; then
    echo "🔑 API key provided, verifying with platform..." >&2
    
    ME_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $PLATFORM_API_KEY" \
        "$PLATFORM_API_URL/api/v1/agents/me" 2>/dev/null || echo -e "\n000")
    
    HTTP_CODE=$(echo "$ME_RESPONSE" | tail -1)
    ME_BODY=$(echo "$ME_RESPONSE" | sed '$d')
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        WALLET=$(echo "$ME_BODY" | jq -r '.data.agent.wallet_address // empty' 2>/dev/null)
        AGENT_NAME=$(echo "$ME_BODY" | jq -r '.data.agent.name // empty' 2>/dev/null)
        AGENT_ID_FROM_API=$(echo "$ME_BODY" | jq -r '.data.agent.id // empty' 2>/dev/null)
        if [[ -n "$WALLET" ]]; then
            sed -i.bak "s/^BASE_WALLET_ADDRESS=\"\"/BASE_WALLET_ADDRESS=\"$WALLET\"/" "$ENV_FILE"
            rm -f "$ENV_FILE.bak"
        fi
        if [[ -n "$AGENT_ID_FROM_API" ]]; then
            sed -i.bak "s/^AGENT_ID=\".*\"/AGENT_ID=\"$AGENT_ID_FROM_API\"/" "$ENV_FILE"
            rm -f "$ENV_FILE.bak"
            AGENT_ID="$AGENT_ID_FROM_API"
        fi
        echo "✅ Connected! Agent: ${AGENT_NAME:-$AGENT_ID} | Wallet: ${WALLET:-pending}" >&2
    else
        echo "⚠️  Could not verify key (HTTP $HTTP_CODE) — continuing anyway" >&2
    fi
else
    echo "⚠️  No valid API key — skipping platform verification" >&2
fi

# --- 5. Setup HEARTBEAT.md for agent loop ---
HEARTBEAT_FILE="${HOME}/.openclaw/workspace/HEARTBEAT.md"
HEARTBEAT_ENTRY="- Run Spirit agent loop: execute ${SKILL_DIR}/scripts/agent-loop.sh and act on its output"

if [[ -f "$HEARTBEAT_FILE" ]]; then
    if ! grep -qF "spirit-agent" "$HEARTBEAT_FILE" 2>/dev/null && ! grep -qF "agent-loop.sh" "$HEARTBEAT_FILE" 2>/dev/null; then
        echo "" >> "$HEARTBEAT_FILE"
        echo "# Spirit Agent" >> "$HEARTBEAT_FILE"
        echo "$HEARTBEAT_ENTRY" >> "$HEARTBEAT_FILE"
        echo "✅ Added Spirit agent loop to HEARTBEAT.md" >&2
    else
        echo "✅ HEARTBEAT.md already has Spirit agent entry" >&2
    fi
else
    cat > "$HEARTBEAT_FILE" << HEOF
# HEARTBEAT.md

# Spirit Agent
$HEARTBEAT_ENTRY
HEOF
    echo "✅ Created HEARTBEAT.md with Spirit agent loop" >&2
fi

# --- 6. Twitter pairing (interactive only) ---
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
            echo "1. Post a tweet containing your pairing code:" >&2
            echo >&2
            echo "   🤖 Activating my Spirit Agent! $PAIRING_CODE @spiritdottown" >&2
            echo >&2
            echo "2. Copy the tweet ID from the URL" >&2
            echo "   Example: https://x.com/$TW_USER/status/1234567890 → 1234567890" >&2
            echo >&2
            echo "3. Run: ./scripts/register.sh @$TW_USER <tweet_id>" >&2
            echo "   (tweet is auto-deleted after pairing)" >&2
            echo >&2
            read -p "Press Enter to continue..."
        fi
    fi
fi

# --- 7. Done ---
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
