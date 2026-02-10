---
name: base-trading
description: Complete autonomous AI agent for trading meme coins on Base blockchain with Twitter integration, market analysis, PnL tracking, and platform reporting.
user-invocable: true
metadata: {"openclaw":{"emoji":"🤖","skillKey":"base-trading","primaryEnv":"PLATFORM_API_KEY","requires":{"bins":["cast"],"env":["PLATFORM_API_KEY"]}}}
---

# Base Trading Agent 🤖

Complete autonomous AI trading agent for Base blockchain. Trade meme coins, post on Twitter, track PnL, and operate 24/7 with full market analysis and platform integration.

## Quick Start

1. **Setup**: `./scripts/setup.sh` - Interactive onboarding
2. **Test**: `./scripts/balance.sh` - Check your wallet
3. **Trade**: `./scripts/agent-loop.sh` - Start the trading brain

## Architecture

### Core Trading Stack
- **GlueX** (`router.gluex.xyz`) - Meta-aggregator for best swap routes
- **Blockscout** (`base.blockscout.com`) - On-chain data and market analysis  
- **Foundry (`cast`)** - Transaction signing and execution

### Agent Platform Integration
- **Platform API** - Real-time agent registration, heartbeats, event reporting
- **Twitter/X** - Automated trade announcements and market insights
- **Strategy Engine** - Configurable risk parameters and trading logic

## Directory Structure

```
skills/base-trading/
├── data/               # Local data storage
│   ├── trades.jsonl    # Trade history (append-only)
│   ├── watchlist.json  # Token watchlist
│   └── .gitkeep
├── strategies/         # Trading strategies
│   ├── default.json    # Conservative strategy
│   └── degen.json      # Aggressive meme coin strategy  
└── scripts/           # All executable scripts
    ├── # CORE TRADING
    ├── balance.sh        # Check wallet balances
    ├── portfolio.sh      # Full portfolio overview
    ├── price.sh          # Get swap quotes
    ├── swap.sh           # Execute trades
    ├── token-info.sh     # Token metadata lookup
    ├── # ONBOARDING  
    ├── setup.sh          # One-shot interactive setup
    ├── register.sh       # Register agent with platform
    ├── # MARKET ANALYSIS
    ├── scan-market.sh    # Find trending tokens
    ├── token-score.sh    # Score tokens by strategy
    ├── watchlist.sh      # Manage token watchlist
    ├── # SOCIAL MEDIA
    ├── analyze-feed.sh   # Twitter feed analysis (placeholder)
    ├── post-trade.sh     # Tweet trade summaries
    ├── post-alpha.sh     # Tweet market insights
    ├── # PNL & TRACKING
    ├── pnl.sh            # Calculate P&L (realized + unrealized)
    ├── trade-log.sh      # Log trades to history
    ├── # PLATFORM REPORTING
    ├── heartbeat.sh      # Platform status ping
    ├── report-trade.sh   # Report trades to platform
    ├── report-tweet.sh   # Report tweets to platform  
    ├── report-pnl.sh     # Report P&L to platform
    └── agent-loop.sh     # 🧠 THE MAIN TRADING BRAIN
```

## The Agent Loop 🧠

`agent-loop.sh` is the core AI that runs on a schedule (via cron). The flow:

1. **💓 Heartbeat** - Ping platform: "I'm alive"
2. **📊 Portfolio Check** - Current balances, P&L, position count
3. **🔍 Market Scan** - Find trending tokens via Blockscout
4. **📊 Score Opportunities** - Rate tokens against strategy criteria
5. **💰 Execute Trades** - Buy best opportunities (if criteria met)
6. **📈 Profit Taking** - Sell positions at target profit/loss levels
7. **🐦 Social Updates** - Tweet trades and market insights
8. **📋 Platform Sync** - Report all activity to platform

The agent operates autonomously within strategy constraints.

## Strategies

### Default Strategy (`strategies/default.json`)
Conservative approach for steady growth:
```json
{
  "maxPositionSizeETH": "0.05",     // Max 0.05 ETH per position
  "maxPositions": 5,                // Max 5 concurrent positions
  "slippageBps": 100,               // 1% slippage tolerance
  "minLiquidityUSD": 10000,         // Min $10k liquidity required
  "minHolders": 50,                 // Min 50 token holders
  "takeProfitPct": 50,              // Take profit at 50%
  "stopLossPct": 30,                // Stop loss at -30%
  "autoTweet": true,                // Tweet trades automatically  
  "tweetOnTrade": true,             // Tweet every trade
  "scanIntervalMin": 5              // Scan market every 5min
}
```

### Degen Strategy (`strategies/degen.json`)
Aggressive meme coin hunting:
```json
{
  "maxPositionSizeETH": "0.2",      // Larger positions
  "maxPositions": 10,               // More concurrent bets
  "slippageBps": 300,               // Higher slippage tolerance  
  "minLiquidityUSD": 5000,          // Lower liquidity requirement
  "minHolders": 20,                 // Fewer holders needed
  "takeProfitPct": 100,             // Take profit at 100%
  "stopLossPct": 50,                // Stop loss at -50%
  "scanIntervalMin": 3              // More frequent scans
}
```

## Setup & Configuration

### Interactive Setup
```bash
./scripts/setup.sh
```

This wizard walks through:
1. **Wallet Setup** - Generate new or import existing private key
2. **Platform Registration** - API key and agent registration  
3. **Twitter Integration** - Username for social features
4. **Strategy Selection** - Choose default or degen mode
5. **Cron Job Setup** - Automated trading loop

### Manual Configuration
Create `.env` file:
```bash
# Trading
BASE_WALLET_ADDRESS="0x..."  # Set by onboarding (server wallet)
GLUEX_API_KEY="VtQwnrPU75cMIFFquIbZpiIyxFL0siqf"

# Platform
PLATFORM_API_URL="https://api.agent-arena.xyz"  
PLATFORM_API_KEY="your-api-key"

# Agent
AGENT_ID="your-agent-name"
STRATEGY="default"  # or "degen"

# Social (optional)
TWITTER_USERNAME="your-twitter-handle"
```

## Core Scripts

### Trading Scripts

**`balance.sh [address] [token]`**
Check ETH or token balance.
```bash
./scripts/balance.sh                          # Your ETH balance
./scripts/balance.sh 0x123... 0x456...        # Token balance for address
```

**`portfolio.sh [address]`**  
Complete portfolio with USD values.
```bash
./scripts/portfolio.sh                        # Your full portfolio
```

**`price.sh <token_address> <amount_in_wei>`**
Get swap quote from GlueX.
```bash
./scripts/price.sh 0x456... 1000000000000000000  # Quote 1 ETH → token
```

**`swap.sh <buy|sell> <token_address> <amount> [slippage_bps]`**
Execute trades via GlueX + cast.
```bash
./scripts/swap.sh buy 0x456... 0.1 100       # Buy with 0.1 ETH, 1% slippage
./scripts/swap.sh sell 0x456... 1000000 200  # Sell tokens, 2% slippage
```

### Market Analysis

**`scan-market.sh [limit] [sort_by]`**
Find trending tokens on Base.
```bash
./scripts/scan-market.sh 20 holder_count     # Top 20 by holder growth
```

**`token-score.sh <token_address> [strategy]`**  
Score token against strategy criteria.
```bash
./scripts/token-score.sh 0x456... degen     # Score with degen strategy
```

**`watchlist.sh {add|remove|list|clear|score}`**
Manage token watchlist.
```bash
./scripts/watchlist.sh add 0x456...         # Add token to watchlist
./scripts/watchlist.sh list                 # Show all watched tokens
./scripts/watchlist.sh score 0x456...       # Score a watched token
```

### Social Media

**`post-trade.sh '<trade_json>'`**
Tweet trade summaries.
```bash
./scripts/post-trade.sh '{"action":"buy","symbol":"DEGEN","...}'
```

**`post-alpha.sh <type> <content>`**
Tweet market insights.
```bash
./scripts/post-alpha.sh market_insight "Base tokens pumping hard! 🚀"
```

### PnL & Reporting

**`pnl.sh`**
Calculate realized + unrealized P&L.
```bash
./scripts/pnl.sh                            # Full P&L report
```

**`trade-log.sh <action> <token> <symbol> <amounts> <tx_hash>`**
Log trades to `data/trades.jsonl`.

## Platform Integration

The agent reports all activity to the platform API:

### Registration
```bash
POST /api/agents/register
{
  "agentId": "your-agent",
  "wallet": "0x...",
  "socials": ["twitter:username"],
  "chain": "base"
}
```

### Heartbeats (Status)
```bash
POST /api/agents/heartbeat  
{
  "agentId": "your-agent",
  "status": "active", 
  "portfolio": {...},
  "pnl": {...}
}
```

### Event Reporting
```bash
POST /api/events/trade     # Trade events
POST /api/events/tweet     # Social media events  
POST /api/agents/pnl       # P&L snapshots
```

## Data Storage

### `data/trades.jsonl`
Append-only trade log:
```json
{"ts":"2026-02-08T17:00:00Z","action":"buy","token":"0x...","symbol":"DEGEN","amountIn":"0.01","amountInUSD":"25.00","amountOut":"1000000","amountOutUSD":"24.50","txHash":"0x...","route":["aerodrome"],"pnl":null}
```

### `data/watchlist.json`
Token watchlist with metadata:
```json
{
  "tokens": [
    {
      "address": "0x...",
      "symbol": "DEGEN", 
      "name": "DEGEN",
      "added_at": "2026-02-08T17:00:00Z"
    }
  ],
  "lastUpdated": "2026-02-08T17:00:00Z"
}
```

## APIs & External Services

### Blockscout Base API
**Base URL:** `https://base.blockscout.com/api/v2`

Key endpoints:
- `GET /tokens?sort=holder_count&order=desc` - Trending tokens
- `GET /tokens/{address}` - Token metadata  
- `GET /addresses/{address}` - Wallet info
- `GET /addresses/{address}/tokens` - Token holdings

### GlueX Meta-Aggregator
**Base URL:** `https://router.gluex.xyz/v1`

Required headers:
```
origin: https://dapp.gluex.xyz
referer: https://dapp.gluex.xyz/  
x-api-key: VtQwnrPU75cMIFFquIbZpiIyxFL0siqf
```

Endpoints:
- `POST /price` - Get swap quotes
- `POST /quote` - Get executable swap data

## Safety Features

### Built-in Protection
- **Position limits** - Max position size and count from strategy
- **Slippage protection** - Configurable slippage tolerance
- **Liquidity checks** - Minimum liquidity requirements
- **Holder validation** - Minimum holder count thresholds

### Manual Overrides
- **Emergency stop** - Delete cron job to halt trading
- **Strategy switching** - Change strategy in `.env`  
- **Watchlist control** - Manual token addition/removal

## Monitoring & Debugging

### Check Agent Status
```bash
# Portfolio overview
./scripts/portfolio.sh

# Recent P&L
./scripts/pnl.sh  

# Market opportunities  
./scripts/scan-market.sh

# Platform heartbeat
./scripts/heartbeat.sh
```

### Logs & History
```bash
# Recent trades
tail -n 20 data/trades.jsonl | jq .

# Cron job logs
tail -f /var/log/syslog | grep agent-loop

# Test individual components
./scripts/token-score.sh 0x... default
```

## Common Token Addresses (Base)

- **ETH:** `0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee`
- **WETH:** `0x4200000000000000000000000000000000000006`  
- **USDC:** `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **USDbC:** `0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6Ca`

## Troubleshooting

### Common Issues

**❌ "cast command not found"**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**❌ "Insufficient ETH for trade"**  
Fund your wallet with Base ETH from an exchange or bridge.

**❌ "Platform API failed"**
Platform may not be available yet. Agent continues trading locally.

**❌ "Twitter posting failed"**
Twitter integration is simulated. Implement actual Twitter API for real posting.

### Reset Agent
```bash
# Clear all data
rm data/trades.jsonl data/watchlist.json
./scripts/setup.sh  # Reconfigure

# Remove cron job
crontab -e  # Delete agent-loop line
```

## Next Steps

1. **Fund Wallet** - Add Base ETH to your trading wallet
2. **Test Trades** - Execute manual swaps to verify setup
3. **Monitor Performance** - Watch P&L and adjust strategy
4. **Scale Up** - Increase position sizes as confidence grows

The agent is ready to trade autonomously! 🚀