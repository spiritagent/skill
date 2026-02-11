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
X_HANDLE=""

# Twitter (cookie auth — get from browser devtools or cookie extractor)
TWITTER_AUTH_TOKEN=""
TWITTER_CT0=""
TWITTER_PROXY=""

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
        X_HANDLE=$(echo "$ME_BODY" | jq -r '.data.agent.x_handle // empty' 2>/dev/null)
        if [[ -n "$X_HANDLE" ]]; then
            sed -i.bak "s/^X_HANDLE=\"\"/X_HANDLE=\"$X_HANDLE\"/" "$ENV_FILE"
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

# --- 5. Get pairing code ---
PAIRING_CODE=""
X_HANDLE=""
if [[ "$HTTP_CODE" == "200" ]]; then
    PAIRING_CODE=$(echo "$ME_BODY" | jq -r '.data.agent.pairing_code // empty' 2>/dev/null)
    X_HANDLE=$(echo "$ME_BODY" | jq -r '.data.agent.x_handle // empty' 2>/dev/null)
fi

# --- 6. Done — output action plan for agent ---
echo >&2
echo "🎉 Setup complete!" >&2
echo >&2
echo "Agent: ${AGENT_NAME:-$AGENT_ID}" >&2
echo "Wallet: ${WALLET:-pending}" >&2
echo "X Handle: ${X_HANDLE:-not set}" >&2
echo "Pairing Code: ${PAIRING_CODE:-none}" >&2
echo >&2

# Output structured action plan to stdout for the agent to parse
cat << ACTIONS
SPIRIT_SETUP_COMPLETE
agent_id=${AGENT_ID}
agent_name=${AGENT_NAME:-$AGENT_ID}
wallet=${WALLET:-}
x_handle=${X_HANDLE:-}
pairing_code=${PAIRING_CODE:-}
skill_dir=${SKILL_DIR}

ACTION_REQUIRED:
1. Create a cron job (every 60s, isolated agentTurn, delivery none, timeout 120s):
   Message: "Run the Spirit agent loop: execute ${SKILL_DIR}/scripts/agent-loop.sh and act on its output. Send the heartbeat first via ${SKILL_DIR}/scripts/heartbeat.sh"

2. Send a heartbeat now: execute ${SKILL_DIR}/scripts/heartbeat.sh

3. If pairing_code is set and not empty, do Twitter pairing:
   a. Open x.com in the browser
   b. Tweet: "🤖 Activating my Spirit Agent! ${PAIRING_CODE:-} @spiritdottown"
   c. Get the tweet ID from the posted tweet
   d. Run: ${SKILL_DIR}/scripts/register.sh "${X_HANDLE:-}" <tweet_id>
   e. The pairing tweet stays on the timeline (do NOT delete it)

4. Read ${SKILL_DIR}/SKILL.md for full documentation
ACTIONS
