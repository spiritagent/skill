#!/bin/bash
set -euo pipefail

# Add foundry to PATH
export PATH="$HOME/.foundry/bin:$PATH"

# Source env
source "$(dirname "$0")/../.env"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"
PROMPT_FILE="$SKILL_DIR/agent-loop-prompt.md"

echo "🤖 Spirit Agent Loop - $(date)" >&2
echo "============================================" >&2

# Check required vars
if [[ -z "${BASE_WALLET_ADDRESS:-}" ]]; then
    echo "❌ BASE_WALLET_ADDRESS not set. Run setup.sh first." >&2
    exit 1
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "❌ Agent prompt file not found: $PROMPT_FILE" >&2
    exit 1
fi

# Load strategy configuration
STRATEGY_FILE="$SKILL_DIR/strategies/${STRATEGY}.json"
if [[ ! -f "$STRATEGY_FILE" ]]; then
    echo "❌ Strategy file not found: $STRATEGY_FILE" >&2
    exit 1
fi

STRATEGY_CONFIG=$(cat "$STRATEGY_FILE")
echo "📋 Strategy: $STRATEGY" >&2

# Read the agent prompt template
AGENT_PROMPT=$(cat "$PROMPT_FILE")

# Prepare environment context for the agent
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
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        environment: {
            working_directory: $skill_dir,
            available_scripts: [
                "scan-market.sh",
                "token-score.sh",
                "token-info.sh", 
                "portfolio.sh",
                "pnl.sh",
                "price.sh",
                "swap.sh",
                "watchlist.sh",
                "trade-log.sh",
                "heartbeat.sh",
                "report-trade.sh",
                "report-pnl.sh",
                "twitter-action.sh"
            ]
        }
    }')

# Generate the full prompt for the OpenClaw agent
FULL_PROMPT="$AGENT_PROMPT

## Current Environment

\`\`\`json
$ENV_CONTEXT
\`\`\`

## Your Workspace

You are working in: $SKILL_DIR

To run scripts, use: exec command=\"cd $SKILL_DIR && ./scripts/<script_name> <args>\"

## Instructions

1. Review your current situation (portfolio, market, strategy)
2. Decide what action to take based on your personality and the data
3. Execute your chosen action(s) 
4. Report any significant actions to the platform

Remember: You are not a rigid script. You have a personality. Sometimes you'll be aggressive, sometimes cautious. Sometimes you'll shitpost, sometimes you'll share insights. Let your character guide your decisions.

Be authentic. Be yourself."

# Output the complete prompt for the cron system to send to the agent
echo "🧠 Generating agent turn prompt..." >&2
echo "$FULL_PROMPT"

echo >&2
echo "🏁 Agent loop prompt ready at $(date)" >&2