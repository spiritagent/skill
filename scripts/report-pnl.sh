#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

echo "📈 Calculating and logging PnL locally..."

# Note: There's no dedicated PnL endpoint on the platform.
# PnL is calculated from trades. This script just logs locally.

# Get PnL data
PNL_DATA=$("$(dirname "$0")/pnl.sh" 2>/dev/null || echo '{}')

# Save to local log with timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="$(dirname "$0")/../data/pnl-log.jsonl"

# Ensure data directory exists
mkdir -p "$(dirname "$0")/../data"

# Log PnL data
echo "$PNL_DATA" | jq --arg timestamp "$TIMESTAMP" '. + {timestamp: $timestamp}' >> "$LOG_FILE"

echo "✅ PnL logged to $LOG_FILE"
echo "$PNL_DATA" | jq .