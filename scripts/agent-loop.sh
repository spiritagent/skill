#!/bin/bash
set -euo pipefail

export PATH="$HOME/.foundry/bin:$PATH"

source "$(dirname "$0")/../.env"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"
PROMPT_FILE="$SKILL_DIR/agent-loop-prompt.md"

echo "🤖 Spirit Agent Loop - $(date)" >&2

# --- Random delay (0-120s) to avoid predictable patterns ---
DELAY=$((RANDOM % 120))
echo "⏱️  Waiting ${DELAY}s..." >&2
sleep "$DELAY"

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

# --- MANDATORY: Heartbeat (always runs, not personality-dependent) ---
echo "💓 Heartbeat..." >&2
"$SCRIPTS_DIR/heartbeat.sh" >/dev/null 2>&1 || echo "⚠️  Heartbeat failed" >&2

# --- Load personality ---
SOUL_FILE="$SKILL_DIR/SOUL.md"
SOUL_CONTENT=""
if [[ -f "$SOUL_FILE" ]]; then
    SOUL_CONTENT=$(cat "$SOUL_FILE")
fi

# --- Build prompt for personality-driven decisions ---
STRATEGY_CONFIG=$(cat "$STRATEGY_FILE")

ENV_CONTEXT=$(jq -n \
    --arg agent_id "${AGENT_ID}" \
    --arg strategy "${STRATEGY}" \
    --argjson strategy_config "$STRATEGY_CONFIG" \
    --arg wallet_address "${BASE_WALLET_ADDRESS}" \
    --arg skill_dir "$SKILL_DIR" \
    --arg scripts_dir "$SCRIPTS_DIR" \
    '{
        agent_id: $agent_id,
        strategy: $strategy,
        strategy_config: $strategy_config,
        wallet_address: $wallet_address,
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

Heartbeat already sent. Now FIRST check your timeline and notifications (mandatory), then do your thing.
PROMPT

echo "🏁 Prompt ready" >&2
