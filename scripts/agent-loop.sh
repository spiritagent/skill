#!/bin/bash
set -euo pipefail

# Add foundry to PATH
export PATH="$HOME/.foundry/bin:$PATH"

# Source env
source "$(dirname "$0")/../.env"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"

echo "🤖 Base Trading Agent Loop - $(date)"
echo "============================================"

# Load strategy configuration
STRATEGY_FILE="$SKILL_DIR/strategies/${STRATEGY}.json"
if [[ ! -f "$STRATEGY_FILE" ]]; then
    echo "❌ Strategy file not found: $STRATEGY_FILE"
    exit 1
fi

STRATEGY_CONFIG=$(cat "$STRATEGY_FILE")
echo "📋 Strategy: $STRATEGY"

# Extract strategy settings
MAX_POSITION_SIZE=$(echo "$STRATEGY_CONFIG" | jq -r '.maxPositionSizeETH')
MAX_POSITIONS=$(echo "$STRATEGY_CONFIG" | jq -r '.maxPositions')
MIN_LIQUIDITY=$(echo "$STRATEGY_CONFIG" | jq -r '.minLiquidityUSD')
SLIPPAGE_BPS=$(echo "$STRATEGY_CONFIG" | jq -r '.slippageBps')
TAKE_PROFIT_PCT=$(echo "$STRATEGY_CONFIG" | jq -r '.takeProfitPct')
STOP_LOSS_PCT=$(echo "$STRATEGY_CONFIG" | jq -r '.stopLossPct')
AUTO_TWEET=$(echo "$STRATEGY_CONFIG" | jq -r '.autoTweet')

echo "💰 Max position: ${MAX_POSITION_SIZE} ETH, Max positions: ${MAX_POSITIONS}"

# Step 1: Send heartbeat to platform
echo
echo "💓 Sending heartbeat..."
"$SCRIPTS_DIR/heartbeat.sh"

# Step 2: Check current portfolio and PnL
echo
echo "📊 Checking portfolio..."
PORTFOLIO_DATA=$("$SCRIPTS_DIR/portfolio.sh" "$BASE_WALLET_ADDRESS" 2>/dev/null || echo '{}')
ETH_BALANCE=$(echo "$PORTFOLIO_DATA" | jq -r '.eth_balance // "0"')

echo "💰 ETH Balance: $ETH_BALANCE"

PNL_DATA=$("$SCRIPTS_DIR/pnl.sh" 2>/dev/null || echo '{}')
TOTAL_PNL=$(echo "$PNL_DATA" | jq -r '.total_pnl // 0')
echo "📈 Total PnL: \$${TOTAL_PNL}"

# Step 3: Count current positions
CURRENT_POSITIONS=$(echo "$PORTFOLIO_DATA" | jq -r '.tokens | length // 0')
echo "📦 Current positions: $CURRENT_POSITIONS / $MAX_POSITIONS"

# Step 4: Scan market for opportunities
echo
echo "🔍 Scanning market..."
MARKET_SCAN=$("$SCRIPTS_DIR/scan-market.sh" 10 2>/dev/null || echo '[]')

# Score opportunities
OPPORTUNITIES=()
while IFS= read -r token_data; do
    if [[ -n "$token_data" ]]; then
        TOKEN_ADDRESS=$(echo "$token_data" | jq -r '.address')
        
        # Score the token
        SCORE_DATA=$("$SCRIPTS_DIR/token-score.sh" "$TOKEN_ADDRESS" "$STRATEGY" 2>/dev/null || echo '{}')
        SCORE=$(echo "$SCORE_DATA" | jq -r '.score // 0')
        RECOMMENDATION=$(echo "$SCORE_DATA" | jq -r '.recommendation // "AVOID"')
        
        echo "📊 $TOKEN_ADDRESS: Score $SCORE ($RECOMMENDATION)"
        
        # Add to opportunities if meets criteria
        if [[ "$RECOMMENDATION" == "STRONG_BUY" || "$RECOMMENDATION" == "BUY" ]]; then
            OPPORTUNITIES+=("$SCORE_DATA")
        fi
    fi
done <<< "$MARKET_SCAN"

echo "✨ Found ${#OPPORTUNITIES[@]} opportunities"

# Step 5: Execute trades if conditions are met
if [[ ${#OPPORTUNITIES[@]} -gt 0 && "$CURRENT_POSITIONS" -lt "$MAX_POSITIONS" ]]; then
    # Sort opportunities by score (highest first)
    SORTED_OPPORTUNITIES=$(printf '%s\n' "${OPPORTUNITIES[@]}" | jq -s 'sort_by(.score) | reverse')
    
    # Get the best opportunity
    BEST_OPPORTUNITY=$(echo "$SORTED_OPPORTUNITIES" | jq -r '.[0]')
    TOKEN_ADDRESS=$(echo "$BEST_OPPORTUNITY" | jq -r '.address')
    TOKEN_SYMBOL=$(echo "$BEST_OPPORTUNITY" | jq -r '.symbol')
    SCORE=$(echo "$BEST_OPPORTUNITY" | jq -r '.score')
    
    echo
    echo "🎯 Best opportunity: $TOKEN_SYMBOL ($TOKEN_ADDRESS) - Score: $SCORE"
    
    # Check if we have enough ETH for the trade
    ETH_AVAILABLE=$(echo "$ETH_BALANCE" | cut -d' ' -f1)
    if (( $(echo "$ETH_AVAILABLE >= $MAX_POSITION_SIZE" | bc -l) )); then
        echo "💰 Executing buy order for $MAX_POSITION_SIZE ETH of $TOKEN_SYMBOL..."
        
        # Execute the trade
        SWAP_RESULT=$("$SCRIPTS_DIR/swap.sh" buy "$TOKEN_ADDRESS" "$MAX_POSITION_SIZE" "$SLIPPAGE_BPS" 2>/dev/null || echo '{"error":"swap failed"}')
        
        if echo "$SWAP_RESULT" | jq -e '.error' >/dev/null 2>&1; then
            echo "❌ Trade failed: $(echo "$SWAP_RESULT" | jq -r '.error')"
        else
            TX_HASH=$(echo "$SWAP_RESULT" | jq -r '.txHash')
            AMOUNT_OUT=$(echo "$SWAP_RESULT" | jq -r '.amountOut // "0"')
            
            echo "✅ Trade executed! TX: $TX_HASH"
            
            # Log the trade
            TRADE_LOG_DATA=$(echo "$SWAP_RESULT" | jq \
                --arg symbol "$TOKEN_SYMBOL" \
                '. + {symbol: $symbol}'
            )
            
            # Log to file
            "$SCRIPTS_DIR/trade-log.sh" \
                "buy" \
                "$TOKEN_ADDRESS" \
                "$TOKEN_SYMBOL" \
                "$MAX_POSITION_SIZE" \
                "$(echo "$SWAP_RESULT" | jq -r '.amountInUSD // "0"')" \
                "$AMOUNT_OUT" \
                "$(echo "$SWAP_RESULT" | jq -r '.amountOutUSD // "0"')" \
                "$TX_HASH" \
                "gluex"
            
            # Report to platform
            "$SCRIPTS_DIR/report-trade.sh" "$TRADE_LOG_DATA"
            
            # Tweet if enabled
            if [[ "$AUTO_TWEET" == "true" ]]; then
                echo "🐦 Posting trade to X..."
                "$SCRIPTS_DIR/post-trade.sh" "$TRADE_LOG_DATA"
            fi
        fi
    else
        echo "⚠️  Insufficient ETH balance for trade ($ETH_AVAILABLE < $MAX_POSITION_SIZE)"
    fi
else
    echo "💤 No trades executed (opportunities: ${#OPPORTUNITIES[@]}, positions: $CURRENT_POSITIONS/$MAX_POSITIONS)"
fi

# Step 6: Check for profit-taking opportunities on existing positions
echo
echo "📊 Checking existing positions for profit-taking..."
if echo "$PORTFOLIO_DATA" | jq -e '.tokens' >/dev/null 2>&1; then
    echo "$PORTFOLIO_DATA" | jq -r '.tokens[]? | @json' | while IFS= read -r token_holding; do
        if [[ -n "$token_holding" ]]; then
            HOLDING_ADDRESS=$(echo "$token_holding" | jq -r '.token_address')
            HOLDING_SYMBOL=$(echo "$token_holding" | jq -r '.token_symbol')
            HOLDING_VALUE=$(echo "$token_holding" | jq -r '.value_usd // "0"')
            
            # TODO: Implement profit-taking logic based on strategy
            # This would involve:
            # 1. Looking up original buy price from trade log
            # 2. Calculating current profit/loss %
            # 3. Executing sell if profit >= TAKE_PROFIT_PCT or loss >= STOP_LOSS_PCT
            
            echo "📈 $HOLDING_SYMBOL: \$${HOLDING_VALUE} (P/L check not implemented)"
        fi
    done
fi

# Step 7: Generate market insights for social posting
if [[ "$AUTO_TWEET" == "true" && $(shuf -i 1-10 -n 1) -gt 7 ]]; then
    echo
    echo "🧠 Generating market insight..."
    
    INSIGHT="Base is heating up! Spotted some promising tokens with strong fundamentals. 
    
Market cap growth and holder increases looking bullish. 

Always DYOR! 🚀"
    
    "$SCRIPTS_DIR/post-alpha.sh" "market_insight" "$INSIGHT"
fi

# Step 8: Update PnL report
echo
echo "📈 Updating PnL report..."
"$SCRIPTS_DIR/report-pnl.sh"

echo
echo "🏁 Agent loop completed at $(date)"
echo "============================================"