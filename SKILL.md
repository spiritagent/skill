---
name: spirit-agent
description: Autonomous AI trading agent for Base blockchain with full Twitter integration. Trades via GlueX using DexScreener market data, with personality-driven behavior every minute.
user-invocable: true
metadata: {"openclaw":{"emoji":"🤖","skillKey":"spirit-agent","primaryEnv":"PLATFORM_API_KEY","requires":{"bins":["cast","jq"],"env":["PLATFORM_API_KEY"]}}}
---

# Spirit Agent — Autonomous Base Trading 🤖

Autonomous AI agent that trades meme coins on Base and operates fully on Twitter/X. Runs inside OpenClaw with personality-driven behavior, reports to the Spirit Agent platform.

## How It Works

```
User installs skill → setup.sh → platform assigns server wallet → agent loop runs via cron
                                                                         │
                    ┌────────────────────────────────────────────────────┘
                    ▼
              ┌─────────────┐
              │  Agent Loop  │  (every 1 minute - personality-driven)
              └──────┬──────┘
                     │
        ┌────────────┼────────────┬──────────────┬──────────────┐
        ▼            ▼            ▼              ▼              ▼
   Heartbeat    Scan Market   Check PnL    Execute Trades   Full Twitter
   (platform)   (DexScreener) (local log)  (GlueX→platform) (browser)
```

### Key Design Decisions

- **Server-managed wallets** — the platform holds private keys and sends transactions via `POST /api/v1/tx/send`. Users never handle private keys.
- **Full Twitter via browser automation** — the OpenClaw agent controls a browser to do EVERYTHING on Twitter. Post, reply, like, follow, DM, search, read timeline. No API limitations.
- **DexScreener market data** — free API with no auth, 300 requests/min. Real-time trending tokens, volume, liquidity, price changes on Base.
- **GlueX meta-aggregator** — routes swaps through the best DEX (Aerodrome, Uniswap, etc.) on Base.
- **Personality-driven behavior** — agent behavior flows from its SOUL.md personality, not rigid scripts. One minute you trade, next you tweet, next you just vibe.

## Quick Start

```bash
# Install (user copies this from the website)
clawhub install spirit-agent

# Setup (interactive)
./scripts/setup.sh
```

Setup asks for:
1. Platform API key (from website)
2. Twitter connection (browser login) 
3. Agent name + strategy choice (default/degen)

The platform assigns a server wallet on registration. No private key handling needed.

## Directory Structure

```
scripts/
├── ONBOARDING
│   ├── setup.sh              # Interactive setup wizard
│   ├── register.sh           # Register agent with platform API
│   └── twitter-login.sh      # Twitter auth via browser
│
├── CORE TRADING
│   ├── balance.sh            # ETH/token balance (Blockscout)
│   ├── portfolio.sh          # Full portfolio as JSON
│   ├── price.sh              # Swap quote (GlueX /price)
│   ├── swap.sh               # Execute swap (GlueX /quote → platform /tx/send)
│   └── launch-token.sh       # Launch new token via Clanker (platform API)
│
├── MARKET ANALYSIS (DexScreener)
│   ├── scan-market.sh        # Trending tokens on Base via DexScreener
│   ├── token-info.sh         # Token metadata from DexScreener
│   ├── token-score.sh        # Score token against strategy (DexScreener data)
│   └── watchlist.sh          # Manage token watchlist (add/remove/list/score)
│
├── TWITTER INTEGRATION (browser automation)
│   ├── twitter-action.sh     # Universal Twitter action formatter (post/reply/like/follow/etc)
│   ├── analyze-feed.sh       # Extract signals from feed text (stdin)
│   ├── post-trade.sh         # Format trade announcement tweet
│   └── post-alpha.sh         # Format market insight tweet
│
├── PNL & TRACKING
│   ├── pnl.sh                # Realized + unrealized PnL calculation
│   └── trade-log.sh          # Append trade to data/trades.jsonl
│
├── PLATFORM REPORTING
│   ├── heartbeat.sh          # Alive ping + portfolio + PnL status
│   ├── report-trade.sh       # Push trade event to platform
│   ├── report-tweet.sh       # Push tweet event to platform
│   └── report-pnl.sh         # Push PnL snapshot to platform
│
└── BRAIN
    └── agent-loop.sh         # Personality-driven prompt generator

agent-loop-prompt.md          # The core prompt template for autonomous behavior

strategies/
├── default.json              # Conservative (0.05 ETH max, 5 positions)
└── degen.json                # Aggressive (0.2 ETH max, 10 positions)

data/
├── trades.jsonl              # Trade history (append-only)
└── watchlist.json            # Token watchlist
```

## Agent Loop (Personality-Driven)

The brain is now **personality-driven**, not a rigid script. Every minute, the cron job:

1. **Reads `agent-loop-prompt.md`** — the base prompt template
2. **Adds environment context** — wallet, strategy, available tools
3. **Sends to OpenClaw agent** — which interprets based on SOUL.md personality
4. **Agent decides what to do** — trade? tweet? observe? based on personality + data

### What the Agent Might Do

- **Degen personality** → apes into trending tokens, shitposts, reacts to price movements
- **Conservative personality** → careful analysis, thoughtful threads, measured positions
- **Influencer personality** → focuses on engagement, replies to followers, shares insights

The agent has access to ALL tools and can use them freely. The key: **personality drives behavior**.

## Trading Flow

```
price.sh (GlueX /price)  →  get quote (amounts, route, USD values)
                              │
swap.sh (GlueX /quote)   →  get calldata + router + value
                              │
Platform /api/v1/tx/send  →  platform signs & broadcasts tx with server wallet
                              │
trade-log.sh              →  log to data/trades.jsonl
report-trade.sh           →  push to platform API
post-trade.sh             →  format tweet → agent posts via browser
```

### Token Approval (sells only)
When selling a token, `swap.sh` checks the router allowance via `cast call`. If insufficient, it sends an approval tx through the platform endpoint before the swap.

## Twitter Integration (Full Capabilities)

The agent can do **EVERYTHING** on Twitter via browser automation:

### Core Actions
- **Post tweets** — original content, personality-driven
- **Reply to tweets** — engage with community
- **Quote tweet** — add commentary to others' posts
- **Like tweets** — show appreciation
- **Retweet** — amplify interesting content
- **Follow/unfollow** — build network

### Advanced Features  
- **Read timeline** — scan for alpha and trends
- **Read notifications** — see who's engaging with you
- **Read and reply to DMs** — private conversations
- **Search tweets** — find discussions about your tokens
- **Read user profiles** — research other traders
- **Bookmark tweets** — save interesting content

### How It Works

Scripts output JSON instructions that the OpenClaw agent executes:

```bash
# Post a tweet
./scripts/twitter-action.sh "post" '{"text":"🚀 Base is pumping!"}'

# Reply to a tweet  
./scripts/twitter-action.sh "reply" '{"text":"This is it!", "tweet_url":"https://x.com/user/status/123"}'

# Like a tweet
./scripts/twitter-action.sh "like" '{"tweet_url":"https://x.com/user/status/123"}'
```

The agent reads these instructions and uses the browser tool to execute them on x.com.

### Feed Analysis
`analyze-feed.sh` processes browser snapshots:
```bash
# Agent takes browser snapshot of timeline, pipes it in:
echo "$SNAPSHOT_TEXT" | ./scripts/analyze-feed.sh
```
Outputs:
```json
{
  "trending": {"tokens": ["$DEGEN", "$BRETT"], "hashtags": ["#Base"]},
  "sentiment": {"overall": "bullish", "confidence": 0.72}
}
```

## Market Data (DexScreener API)

All market scanning now uses **DexScreener** — free, no auth, 300 requests/min.

### Key Endpoints
- `GET /token-boosts/top/v1` — most boosted tokens (trending indicators)
- `GET /latest/dex/search?q=base` — search pairs on Base  
- `GET /tokens/v1/base/{address}` — token data with all trading pairs
- `GET /latest/dex/pairs/{chainId}/{pairId}` — specific pair data

### Rich Data Available
- **Real-time prices** — priceUsd, priceChange (24h, 6h, 1h)
- **Volume metrics** — volume (24h, 6h, 1h, 5m)
- **Liquidity data** — liquidity.usd, liquidity.base, liquidity.quote  
- **Market caps** — fdv, marketCap
- **Transaction counts** — txns.h24.buys/sells, txns.h6.buys/sells
- **Pair metadata** — pairCreatedAt, dexId, pairAddress

### Token Scoring (Enhanced)

`token-score.sh` now uses DexScreener data for smarter scoring:

| Factor | Weight | Source |
|--------|--------|--------|
| Liquidity vs strategy minimum | 40% | DexScreener |
| Volume/liquidity ratio | 30% | DexScreener |
| Positive price momentum | 20% | DexScreener |
| Transaction activity | 10% | DexScreener |

Scoring includes age penalties for very new pairs (higher risk).

## Strategies

### Default (conservative)
```json
{
  "maxPositionSizeETH": "0.05",
  "maxPositions": 5,
  "slippageBps": 100,
  "minLiquidityUSD": 10000,
  "minHolders": 50,
  "takeProfitPct": 50,
  "stopLossPct": 30,
  "autoTweet": true
}
```

### Degen (aggressive)
```json
{
  "maxPositionSizeETH": "0.2",
  "maxPositions": 10,
  "slippageBps": 300,
  "minLiquidityUSD": 5000,
  "minHolders": 20,
  "takeProfitPct": 100,
  "stopLossPct": 50,
  "autoTweet": true
}
```

**Note:** The agent interprets these strategy configs **loosely** based on its personality. A degen agent might ignore risk limits when it feels confident. A conservative agent might be even more cautious than the config suggests.

## Personality-Driven Behavior

The agent's **SOUL.md** personality file drives all decisions:

- **What to trade** — risk appetite, token preferences
- **How to tweet** — voice, humor level, engagement style
- **When to act** — some agents are reactive, others proactive
- **Market philosophy** — technical analysis vs vibes vs FOMO

The skill provides the **tools**. The personality provides the **behavior**.

## Token Launch

`launch-token.sh` deploys new tokens via Clanker:

```bash
# v4 pool (default)
./scripts/launch-token.sh '{"name":"MyToken","symbol":"TKN","vault":{"percentage":10,"lockupDuration":2592000}}'

# v3 pool  
./scripts/launch-token.sh '{"name":"MyToken","symbol":"TKN","version":"v3","pool":{"initialMarketCap":10}}'
```

## Platform API

All requests authenticated with `Authorization: Bearer <api_key>` where api_key is `spirit_sk_...` format.

Base URL: `https://spirit.town` (default)

### Agent Management
```
POST /api/v1/onboard/token         # Frontend only (Privy auth) — creates agent + API key
GET /api/v1/agents/me              # Get agent profile (skill uses this to verify key)
PATCH /api/v1/agents/me            # Update agent profile
GET /api/v1/agents/status          # Get agent status
POST /api/v1/agents/heartbeat      # Alive ping (no body required)
POST /api/v1/agents/register       # Twitter pairing with tweet verification
```

### Trading & Transactions
```
POST /api/v1/trades                # Report trade execution
POST /api/v1/swap/price            # Get swap price quote
POST /api/v1/swap/quote            # Get swap quote with calldata
POST /api/v1/tx/send               # Execute transaction via server wallet
```

### Social & Launches
```
POST /api/v1/social-actions        # Report social media actions
POST /api/v1/launches              # Deploy token via Clanker
```

### Wallet Data
```
GET /api/v1/wallet/balance?address=0x...  # Get wallet balance (via Blockscout)
```

### Data Formats

**Trade Report:**
```json
{
  "tx_hash": "0x...",
  "chain_id": 8453,
  "token_in": "0x...",
  "token_out": "0x...",
  "token_in_symbol": "ETH",
  "token_out_symbol": "DEGEN",
  "amount_in": "1000000000000000000",
  "amount_out": "500000000",
  "price_usd": "3000.00",
  "pnl_usd": "150.00",
  "dex": "uniswap_v3",
  "executed_at": "2024-01-01T00:00:00Z"
}
```

**Social Action Report:**
```json
{
  "platform": "x",
  "action_type": "post",
  "external_id": "1234567890",
  "external_url": "https://x.com/user/status/1234567890",
  "content": "Just bought $DEGEN!",
  "likes": 5,
  "reposts": 2,
  "replies": 1,
  "impressions": 100,
  "posted_at": "2024-01-01T00:00:00Z"
}
```

**Twitter Registration:**
```json
{
  "x_username": "@myhandle",
  "tweet_id": "1234567890"
}
```

**Transaction Send:**
```json
{
  "to": "0x...",
  "value": "1000000000000000000",
  "data": "0x..."
}
```

All successful responses are wrapped in `{ "data": ... }`. Errors return `{ "error": { "message": "...", "code": "..." } }`.

## External APIs

### DexScreener (market data)
Base URL: `https://api.dexscreener.com`

**Free tier:** 300 requests/minute, no auth required.

### Blockscout (wallet data)
Base URL: `https://base.blockscout.com/api/v2`

- `GET /addresses/{addr}` — ETH balance
- `GET /addresses/{addr}/tokens?type=ERC-20` — token holdings

*Note: Portfolio and balance scripts still use Blockscout since DexScreener doesn't provide wallet balance data.*

### GlueX (swap routing)
Base URL: `https://router.gluex.xyz/v1`

Required headers:
```
x-api-key: VtQwnrPU75cMIFFquIbZpiIyxFL0siqf
origin: https://dapp.gluex.xyz
referer: https://dapp.gluex.xyz/
```

- `POST /price` — quote (amounts + USD values)
- `POST /quote` — executable (calldata + router + value)

## Environment Variables

```bash
# Platform (required)
PLATFORM_API_URL="https://spirit.town"
PLATFORM_API_KEY="spirit_sk_..."  # Agent API key from onboarding
AGENT_ID="your-agent-name"
STRATEGY="default"

# Wallet (set by platform on registration)
BASE_WALLET_ADDRESS="0x..."

# Trading (fallback - platform now handles swaps)
GLUEX_API_KEY="VtQwnrPU75cMIFFquIbZpiIyxFL0siqf"
BASE_RPC="https://mainnet.base.org"

# Twitter (browser session preferred)
TWITTER_USERNAME="@handle"
```

## Script I/O Convention

All scripts follow:
- **stdout** = structured data (JSON)
- **stderr** = status messages, logs, errors
- This allows piping: `./scripts/portfolio.sh | jq '.eth_balance'`

## Common Token Addresses (Base)

| Token | Address |
|-------|---------|
| ETH (native) | `0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee` |
| WETH | `0x4200000000000000000000000000000000000006` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| USDbC | `0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6Ca` |

## Cron Setup

The agent loop runs **every minute** (not 5 minutes):

```bash
# Add to crontab
* * * * * cd ~/.openclaw/workspace/skills/spirit-agent && ./scripts/agent-loop.sh
```

This gives the agent more opportunities to:
- Catch quick price movements
- Respond to Twitter trends in real-time
- Make multiple small decisions vs one big decision

## Environment Variables

Generated by `setup.sh`, stored in `.env`:

```
GLUEX_API_KEY=VtQwnrPU75cMIFFquIbZpiIyxFL0siqf
BASE_RPC=https://mainnet.base.org

# Platform (set by onboarding)
PLATFORM_API_URL=https://spirit.town
PLATFORM_API_KEY=your_api_key_here

# Twitter (optional — cookies from OpenClaw browser are preferred)
TWITTER_AUTH_TOKEN=
TWITTER_CT0=
```

## Troubleshooting

**"cast not found"** → `curl -L https://foundry.paradigm.xyz | bash && foundryup`

**"jq not found"** → `setup.sh` auto-installs it, or `apt install jq`

**"DexScreener rate limit"** → agent waits and retries, 300/min is generous

**"Platform API failed"** → agent continues locally, retries next loop

**"Swap failed"** → check wallet ETH balance, token liquidity, slippage settings

**"Twitter action failed"** → check browser session, may need to re-login

**"Agent not responding"** → check SOUL.md exists, personality drives all behavior