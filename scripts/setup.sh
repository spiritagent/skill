#!/bin/bash
set -euo pipefail

# Add foundry to PATH
export PATH="$HOME/.foundry/bin:$PATH"

# Source env if it exists
ENV_FILE="$(dirname "$0")/../.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "🚀 Base Trading Agent Setup"
echo "=========================="
echo

# Auto-install jq if missing
if ! command -v jq >/dev/null 2>&1; then
    echo "📦 jq not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq jq
    elif command -v brew >/dev/null 2>&1; then
        brew install jq
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y jq
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache jq
    else
        echo "❌ Could not auto-install jq. Install manually."
        exit 1
    fi
fi

echo "✅ jq found"

# Auto-install Foundry (cast) if missing
if ! command -v cast >/dev/null 2>&1; then
    echo "📦 Foundry (cast) not found. Installing..."
    curl -L https://foundry.paradigm.xyz | bash
    export PATH="$HOME/.foundry/bin:$PATH"
    foundryup
    if ! command -v cast >/dev/null 2>&1; then
        echo "❌ Foundry installation failed."
        exit 1
    fi
fi

echo "✅ Foundry found"

# 1. Platform API setup
echo
echo "🌐 Platform API Setup"
echo "---------------------"
echo
PLATFORM_API_URL="${PLATFORM_API_URL:-https://api.agent-arena.xyz}"
echo "Platform API URL: $PLATFORM_API_URL"

read -p "Platform API key (or press Enter to skip): " PLATFORM_API_KEY

# 3. Twitter/X setup via OpenClaw browser
echo
echo "🐦 Twitter/X Setup (Optional)"
echo "-----------------------------"
echo
read -p "Connect Twitter account? (y/N): " connect_twitter
TWITTER_USERNAME=""

if [[ "$connect_twitter" =~ ^[Yy] ]]; then
    read -p "Twitter @username: " TWITTER_USERNAME
    echo
    echo "Opening X/Twitter login in OpenClaw browser..."
    echo "Please log in manually — your session will persist."
    "$SKILL_DIR/scripts/twitter-login.sh" && echo "✅ Twitter connected!" || {
        echo "⚠️  Twitter login skipped. You can run ./scripts/twitter-login.sh later."
    }
fi

# 4. Agent configuration
echo
echo "🤖 Agent Configuration"
echo "----------------------"
echo
read -p "Agent ID/name: " AGENT_ID
echo "Available strategies: default, degen"
read -p "Strategy (default/degen) [default]: " STRATEGY
STRATEGY="${STRATEGY:-default}"

# 5. Write .env file
echo
echo "Writing configuration..."
cat > "$ENV_FILE" << EOF
# Base Trading Agent Configuration
GLUEX_API_KEY="VtQwnrPU75cMIFFquIbZpiIyxFL0siqf"

# Platform
PLATFORM_API_URL="$PLATFORM_API_URL"
PLATFORM_API_KEY="$PLATFORM_API_KEY"

# Agent
AGENT_ID="$AGENT_ID"
STRATEGY="$STRATEGY"

# Twitter (optional — session managed by OpenClaw browser)
TWITTER_USERNAME="$TWITTER_USERNAME"

# Paths
export PATH="\$HOME/.foundry/bin:\$PATH"
EOF

echo "✅ Configuration saved to $ENV_FILE"

# 6. Register with platform
echo
echo "🔗 Platform Registration"
echo "------------------------"
echo
if [[ -n "${PLATFORM_API_KEY:-}" ]]; then
    echo "Registering agent with platform..."
    "$SKILL_DIR/scripts/register.sh" || echo "⚠️  Registration failed (platform may not be available yet)"
else
    echo "⚠️  Skipping platform registration (no API key)"
fi

# 7. Setup cron job
echo
echo "⏰ Cron Job Setup"
echo "----------------"
echo
read -p "Setup automatic trading loop? (y/N): " setup_cron
if [[ "$setup_cron" =~ ^[Yy] ]]; then
    read -p "Interval in minutes [5]: " INTERVAL
    INTERVAL="${INTERVAL:-5}"
    
    CRON_COMMAND="cd $SKILL_DIR && ./scripts/agent-loop.sh"
    CRON_LINE="*/$INTERVAL * * * * $CRON_COMMAND"
    
    echo "Adding cron job: $CRON_LINE"
    (crontab -l 2>/dev/null || echo "") | grep -v "agent-loop.sh" | { cat; echo "$CRON_LINE"; } | crontab -
    echo "✅ Cron job added"
else
    echo "⚠️  Skipping cron setup. Run manually with: $SKILL_DIR/scripts/agent-loop.sh"
fi

echo
echo "🎉 Setup Complete!"
echo "=================="
echo
echo "Your agent is configured with:"
echo "  Strategy: $STRATEGY"
echo "  Agent ID: $AGENT_ID"
echo "  Wallet: managed by Spirit (server wallet)"
echo
echo "Next steps:"
echo "  1. Fund your wallet with Base ETH"
echo "  2. Test with: $SKILL_DIR/scripts/balance.sh"
echo "  3. Start trading with: $SKILL_DIR/scripts/agent-loop.sh"
echo