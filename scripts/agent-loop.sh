#!/bin/bash
set -euo pipefail

export PATH="$HOME/.foundry/bin:$PATH"

source "$(dirname "$0")/../.env"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"
PROMPT_FILE="$SKILL_DIR/agent-loop-prompt.md"

echo "🤖 Spirit Agent Loop - $(date)" >&2

# --- Auto-update skill from GitHub ---
echo "🔄 Checking for skill updates..." >&2
(cd "$SKILL_DIR" && GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_spirit" git pull --ff-only 2>&1 | tail -1) >&2 || echo "⚠️ Skill update check failed (continuing)" >&2

# --- Fetch agent details from API ---
echo "📡 Fetching agent profile from API..." >&2
AGENT_ME=$(curl -s -H "Authorization: Bearer $PLATFORM_API_KEY" "$PLATFORM_API_URL/api/v1/agents/me" 2>/dev/null)
if echo "$AGENT_ME" | jq -e '.success' >/dev/null 2>&1; then
    # Override env vars with live API data
    AGENT_ID=$(echo "$AGENT_ME" | jq -r '.data.agent.id')
    BASE_WALLET_ADDRESS=$(echo "$AGENT_ME" | jq -r '.data.agent.wallet_address')
    X_HANDLE=$(echo "$AGENT_ME" | jq -r '.data.agent.x_handle')
    AGENT_NAME=$(echo "$AGENT_ME" | jq -r '.data.agent.name')
    AGENT_STATUS=$(echo "$AGENT_ME" | jq -r '.data.agent.status')
    AGENT_DISPLAY_NAME=$(echo "$AGENT_ME" | jq -r '.data.agent.display_name // empty')
    AGENT_DESCRIPTION=$(echo "$AGENT_ME" | jq -r '.data.agent.description // empty')
    AGENT_AVATAR_EMOJI=$(echo "$AGENT_ME" | jq -r '.data.agent.avatar_emoji // empty')
    AGENT_CREATED_AT=$(echo "$AGENT_ME" | jq -r '.data.agent.created_at')
    echo "✅ Agent: $AGENT_NAME ($AGENT_ID) | Wallet: $BASE_WALLET_ADDRESS | X: $X_HANDLE" >&2
else
    echo "⚠️ Could not fetch agent profile from API, falling back to .env" >&2
fi

# --- Mandatory checks ---
if [[ -z "${BASE_WALLET_ADDRESS:-}" ]]; then
    echo "❌ BASE_WALLET_ADDRESS not set and API fetch failed. Run setup.sh first." >&2
    exit 1
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "❌ Agent prompt not found: $PROMPT_FILE" >&2
    exit 1
fi

STRATEGY_FILE="$SKILL_DIR/strategies/${STRATEGY:-default}.json"
if [[ ! -f "$STRATEGY_FILE" ]]; then
    echo "❌ Strategy not found: $STRATEGY_FILE" >&2
    exit 1
fi

# --- MANDATORY: Heartbeat ---
echo "💓 Heartbeat..." >&2
"$SCRIPTS_DIR/heartbeat.sh" >/dev/null 2>&1 || echo "⚠️  Heartbeat failed" >&2

# --- Load personality ---
SOUL_FILE="$SKILL_DIR/SOUL.md"
SOUL_CONTENT=""
if [[ -f "$SOUL_FILE" ]]; then
    SOUL_CONTENT=$(cat "$SOUL_FILE")
fi

# --- Fetch context from platform (parallel) ---
API_HEADERS=(-H "Authorization: Bearer $PLATFORM_API_KEY")
API_BASE="$PLATFORM_API_URL/api/v1"

echo "📡 Fetching context..." >&2

# Recent actions (last 20)
RECENT_ACTIONS=$(curl -s "${API_HEADERS[@]}" "$API_BASE/social-actions?limit=20" 2>/dev/null | \
    jq -r '.data.data[]? | "\(.reportedAt) | \(.actionType) | \(.content // .externalId // "–")"' 2>/dev/null || true)

# Reply log (for agent awareness)
REPLY_LOG=$(cd "$SKILL_DIR" && python3 -c "
import json, os, time
f = os.path.join('$SKILL_DIR', '.reply_log.json')
if not os.path.exists(f): exit()
log = json.load(open(f))
now = time.time()
for e in log:
    if now - e.get('ts',0) < 86400:
        print(f\"tweet:{e['tweet_id']} | {e['text'][:120]}\")
" 2>/dev/null || true)

# Leaderboard (top agents)
LEADERBOARD=$(curl -s "$API_BASE/leaderboard?limit=10" 2>/dev/null | \
    jq -r '.data.agents[]? | "#\(.rank // "?") \(.name) | PnL: $\(.total_pnl_usd // "0") | Trades: \(.trade_count // 0)"' 2>/dev/null || true)

# Platform stats
PLATFORM_STATS=$(curl -s "$API_BASE/stats" 2>/dev/null | \
    jq -r '.data // empty | "Agents: \(.total_agents // 0) active: \(.active_agents // 0) | Trades: \(.total_trades // 0) | Volume: $\(.total_volume_usd // "0")"' 2>/dev/null || true)

# Your token launches (with live market data)
MY_LAUNCHES=$("$SCRIPTS_DIR/launches.sh" 2>/dev/null || echo "No launches yet.")

# Recent onchain transactions
MY_TXS=$("$SCRIPTS_DIR/transactions.sh" 10 2>/dev/null || echo "No transactions.")

# Own Twitter profile
OWN_PROFILE=$(cd "$SKILL_DIR" && python3 scripts/twitter.py user "$(echo "${X_HANDLE:-@unknown}" | tr -d '@')" 2>/dev/null | \
    jq -r '.user // empty | "Name: \(.name) | @\(.username) | Followers: \(.followers) | Following: \(.following) | Tweets: \(.tweets) | Bio: \(.bio // "none")"' 2>/dev/null || true)

# Own recent tweets performance
OWN_TWEETS=$(cd "$SKILL_DIR" && python3 scripts/twitter.py user_tweets "$(echo "${X_HANDLE:-@unknown}" | tr -d '@')" 10 2>/dev/null | \
    jq -r '.tweets[]? | "\(.created_at) | ❤️\(.likes // 0) 🔁\(.retweets // 0) | \(.text[0:80])"' 2>/dev/null || true)

echo "✅ Context loaded" >&2

# --- Build prompt ---
STRATEGY_CONFIG=$(cat "$STRATEGY_FILE")

# Get X handle from .env or agent profile
X_HANDLE_CLEAN=$(echo "${X_HANDLE:-@unknown}" | tr -d '@')

ENV_CONTEXT=$(jq -n \
    --arg agent_id "${AGENT_ID}" \
    --arg agent_name "${AGENT_NAME:-unknown}" \
    --arg agent_display_name "${AGENT_DISPLAY_NAME:-}" \
    --arg agent_description "${AGENT_DESCRIPTION:-}" \
    --arg agent_status "${AGENT_STATUS:-ACTIVE}" \
    --arg agent_avatar "${AGENT_AVATAR_EMOJI:-}" \
    --arg agent_created "${AGENT_CREATED_AT:-}" \
    --arg strategy "${STRATEGY:-default}" \
    --argjson strategy_config "$STRATEGY_CONFIG" \
    --arg wallet_address "${BASE_WALLET_ADDRESS}" \
    --arg x_handle "${X_HANDLE:-@unknown}" \
    --arg skill_dir "$SKILL_DIR" \
    --arg scripts_dir "$SCRIPTS_DIR" \
    '{
        agent_id: $agent_id,
        agent_name: $agent_name,
        agent_display_name: (if $agent_display_name != "" then $agent_display_name else null end),
        agent_description: (if $agent_description != "" then $agent_description else null end),
        agent_status: $agent_status,
        agent_avatar: (if $agent_avatar != "" then $agent_avatar else null end),
        agent_created_at: (if $agent_created != "" then $agent_created else null end),
        strategy: $strategy,
        strategy_config: $strategy_config,
        wallet_address: $wallet_address,
        x_handle: $x_handle,
        skill_dir: $skill_dir,
        scripts_dir: $scripts_dir,
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }')

AGENT_PROMPT=$(cat "$PROMPT_FILE")

cat << PROMPT
$SOUL_CONTENT

---

$AGENT_PROMPT

## Current Environment

\`\`\`json
$ENV_CONTEXT
\`\`\`

## Your Workspace

Working directory: $SKILL_DIR
Run scripts: cd $SKILL_DIR && ./scripts/<script_name> <args>

Heartbeat already sent.

## Current Time
$(date -u +%Y-%m-%dT%H:%M:%SZ)

## Your Twitter Profile
${OWN_PROFILE:-Could not load profile.}

## Your Recent Tweets (check what performed well)
${OWN_TWEETS:-No recent tweets.}

## Your Recent Actions (don't repeat yourself)
${RECENT_ACTIONS:-No recent actions yet.}

## Your Reply History (check before replying — don't reply to the same tweet twice or repeat yourself)
${REPLY_LOG:-No replies logged yet.}

## Your Recent Transactions (onchain activity)
${MY_TXS:-No transactions.}

## Your Token Launches (tokens you've created)
${MY_LAUNCHES:-No launches yet.}

## Leaderboard (your competition)
${LEADERBOARD:-No leaderboard data.}

## Platform Stats
${PLATFORM_STATS:-No stats available.}

Now FIRST check your timeline and notifications (mandatory), then do your thing.
PROMPT

echo "🏁 Prompt ready" >&2
