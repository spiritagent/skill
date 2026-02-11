#!/bin/bash
set -euo pipefail

export PATH="$HOME/.foundry/bin:$PATH"

source "$(dirname "$0")/../.env"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"
PROMPT_FILE="$SKILL_DIR/agent-loop-prompt.md"

echo "🤖 Spirit Agent Loop - $(date)" >&2

# --- Mandatory checks ---
if [[ -z "${BASE_WALLET_ADDRESS:-}" ]]; then
    echo "❌ BASE_WALLET_ADDRESS not set. Run setup.sh first." >&2
    exit 1
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "❌ Agent prompt not found: $PROMPT_FILE" >&2
    exit 1
fi

STRATEGY_FILE="$SKILL_DIR/strategies/${STRATEGY}.json"
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

# Leaderboard (top agents)
LEADERBOARD=$(curl -s "$API_BASE/leaderboard?limit=10" 2>/dev/null | \
    jq -r '.data.agents[]? | "#\(.rank // "?") \(.name) | PnL: $\(.total_pnl_usd // "0") | Trades: \(.trade_count // 0)"' 2>/dev/null || true)

# Platform stats
PLATFORM_STATS=$(curl -s "$API_BASE/stats" 2>/dev/null | \
    jq -r '.data // empty | "Agents: \(.total_agents // 0) active: \(.active_agents // 0) | Trades: \(.total_trades // 0) | Volume: $\(.total_volume_usd // "0")"' 2>/dev/null || true)

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
    --arg strategy "${STRATEGY}" \
    --argjson strategy_config "$STRATEGY_CONFIG" \
    --arg wallet_address "${BASE_WALLET_ADDRESS}" \
    --arg x_handle "${X_HANDLE:-@unknown}" \
    --arg skill_dir "$SKILL_DIR" \
    --arg scripts_dir "$SCRIPTS_DIR" \
    '{
        agent_id: $agent_id,
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

## Leaderboard (your competition)
${LEADERBOARD:-No leaderboard data.}

## Platform Stats
${PLATFORM_STATS:-No stats available.}

Now FIRST check your timeline and notifications (mandatory), then do your thing.
PROMPT

echo "🏁 Prompt ready" >&2
