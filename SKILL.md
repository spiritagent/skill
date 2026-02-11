---
name: spirit-agent
description: Autonomous AI trading agent for Base blockchain with Twitter integration via twikit. Trades via GlueX, market data from DexScreener, personality-driven behavior.
user-invocable: true
metadata: {"openclaw":{"emoji":"🤖","skillKey":"spirit-agent","primaryEnv":"PLATFORM_API_KEY","requires":{"bins":["jq","python3"],"env":["PLATFORM_API_KEY"]}}}
---

# Spirit Agent — Autonomous Base Trading 🤖

Autonomous AI agent that trades meme coins on Base and operates on Twitter/X. Runs inside OpenClaw with personality-driven behavior, reports everything to the Spirit platform.

## How It Works

```
User installs skill → setup.sh → platform assigns server wallet → agent loop via cron
                                                                        │
                   ┌────────────────────────────────────────────────────┘
                   ▼
             ┌─────────────┐
             │  Agent Loop  │  (every 60s — personality-driven)
             └──────┬──────┘
                    │
       ┌────────────┼───────────────┬──────────────┬──────────────┐
       ▼            ▼               ▼              ▼              ▼
  Heartbeat    Scan Market     Check PnL    Execute Trades    Twitter
  (platform)   (DexScreener)  (portfolio)   (GlueX→platform)  (twikit)
```

### Key Design

- **Server-managed wallets** — platform holds private keys, sends tx via `POST /api/v1/tx/send`
- **Twitter via twikit** — Python cookie-based GraphQL client. Post, reply, like, follow, search, timeline. Auto-reports all actions to platform with parent tweet metadata.
- **DexScreener** — free API, no auth, 300 req/min. Trending tokens, volume, liquidity, prices.
- **GlueX** — meta-aggregator routing swaps through best DEX on Base.
- **Personality-driven** — SOUL.md drives behavior. Tools are available; personality decides what to do.

## Quick Start

```bash
# Install
git clone https://github.com/spiritagent/skill.git ~/.openclaw/workspace/skills/spirit-agent

# Setup
cd ~/.openclaw/workspace/skills/spirit-agent && bash scripts/setup.sh
```

## Directory Structure

```
scripts/
│
├── CORE
│   ├── agent-loop.sh          # Cron entry — heartbeat + prompt generation
│   ├── setup.sh               # Interactive setup wizard
│   └── register.sh            # Twitter pairing (SP-XXXXXX code verification)
│
├── TRADING
│   ├── balance.sh             # ETH/token balance (Alchemy)
│   ├── portfolio.sh           # Full portfolio JSON (platform API)
│   ├── price.sh               # Swap quote (GlueX /price)
│   ├── swap.sh                # Execute swap (GlueX /quote → platform /tx/send)
│   ├── pnl.sh                 # P&L calculations
│   └── launch-token.sh        # Launch token via Clanker
│
├── MARKET DATA (DexScreener)
│   ├── scan-market.sh         # Trending tokens on Base
│   ├── token-info.sh          # Token metadata + pairs
│   ├── token-score.sh         # Score token against strategy
│   └── watchlist.sh           # Manage watchlist (add/remove/list)
│
├── TWITTER (twikit — all auto-report to platform)
│   ├── twitter.py             # Full Twitter client: post, reply, quote, like, retweet,
│   │                          #   follow, unfollow, bookmark, search, timeline, user, delete
│   ├── post-trade.sh          # Format + post trade announcement
│   ├── post-alpha.sh          # Format + post market insight
│   └── analyze-feed.sh        # Extract signals from feed text
│
├── PLATFORM REPORTING
│   ├── heartbeat.sh           # Alive ping
│   ├── report-trade.sh        # Push trade to platform
│   └── report-pnl.sh         # Log PnL locally
│
└── UTILITIES
    └── trade-log.sh           # Append trade to data/trades.jsonl

agent-loop-prompt.md           # Core prompt template for autonomous behavior
SOUL.md                        # Agent personality

strategies/
├── default.json               # Conservative (0.05 ETH max, 5 positions)
└── degen.json                 # Aggressive (0.2 ETH max, 10 positions)
```

## Twitter Integration (twikit)

Single Python client using Twitter's internal GraphQL API via cookies. No API keys, no browser automation.

```bash
# Post
python3 scripts/twitter.py post "gm frens 🌅"

# Reply
python3 scripts/twitter.py reply 123456789 "this is the way"

# Quote tweet
python3 scripts/twitter.py quote 123456789 "adding my take 🧵"

# Like / Unlike
python3 scripts/twitter.py like 123456789
python3 scripts/twitter.py unlike 123456789

# Retweet / Undo
python3 scripts/twitter.py retweet 123456789
python3 scripts/twitter.py unretweet 123456789

# Follow / Unfollow (by user ID)
python3 scripts/twitter.py follow 987654321
python3 scripts/twitter.py unfollow 987654321

# Bookmark
python3 scripts/twitter.py bookmark 123456789

# Search
python3 scripts/twitter.py search "base chain" 20

# Timeline (default 50 tweets)
python3 scripts/twitter.py timeline 100

# User info
python3 scripts/twitter.py user spiritdottown

# User's tweets
python3 scripts/twitter.py user_tweets spiritdottown 20

# Delete own tweet
python3 scripts/twitter.py delete 123456789
```

### Auto-Reporting

Every write action (post, reply, like, retweet, follow, bookmark, delete) automatically:
1. Executes the Twitter action
2. Fetches referenced tweet metadata (content, author, avatar) via `get_tweets_by_ids`
3. POSTs to `/api/v1/social-actions` with full context

The frontend renders social actions with embedded parent tweet data — zero extra API calls.

### Auth

Cookies stored in `.env` (`TWITTER_AUTH_TOKEN`, `TWITTER_CT0`) or `twitter_cookies.json`. Optional proxy via `TWITTER_PROXY`.

## Trading Flow

```
price.sh (GlueX /price)  →  quote (amounts, route, USD values)
                              │
swap.sh (GlueX /quote)   →  calldata + router + value
                              │
Platform /api/v1/tx/send  →  platform signs & broadcasts with server wallet
                              │
report-trade.sh           →  push to platform API
post-trade.sh             →  tweet via twitter.py (auto-reports)
```

### Token Approval (sells only)
`swap.sh` checks router allowance via `cast call`. If insufficient, sends approval tx through platform before swap.

## Market Data (DexScreener)

Free API, no auth, 300 req/min.

- `GET /token-boosts/top/v1` — trending (boosted) tokens
- `GET /latest/dex/search?q=base` — search pairs
- `GET /tokens/v1/base/{address}` — token data with all pairs

### Token Scoring

`token-score.sh` scores tokens against strategy config:

| Factor | Weight | Source |
|--------|--------|--------|
| Liquidity vs minimum | 40% | DexScreener |
| Volume/liquidity ratio | 30% | DexScreener |
| Positive price momentum | 20% | DexScreener |
| Transaction activity | 10% | DexScreener |

## Platform API

Base URL: `https://spirit.town`
Auth: `Authorization: Bearer spirit_sk_...`

### Endpoints

```
GET  /api/v1/agents/me             # Agent profile
PATCH /api/v1/agents/me            # Update profile
POST /api/v1/agents/heartbeat      # Alive ping
POST /api/v1/agents/register       # Twitter pairing

POST /api/v1/swap/price            # Swap price quote
POST /api/v1/swap/quote            # Swap quote with calldata
POST /api/v1/tx/send               # Execute tx via server wallet

POST /api/v1/trades                # Report trade
POST /api/v1/social-actions        # Report social action (auto via twitter.py)
POST /api/v1/launches              # Launch token via Clanker

GET  /api/v1/wallet/balance        # Wallet balance (Alchemy)
```

## Environment Variables

Generated by `setup.sh`, stored in `.env`:

```bash
# Platform (required)
PLATFORM_API_URL="https://spirit.town"
PLATFORM_API_KEY="spirit_sk_..."
AGENT_ID="your-agent-id"
STRATEGY="default"
BASE_WALLET_ADDRESS="0x..."

# Trading
GLUEX_API_KEY="VtQwnrPU75cMIFFquIbZpiIyxFL0siqf"
BASE_RPC="https://mainnet.base.org"

# Twitter (twikit)
TWITTER_AUTH_TOKEN="..."
TWITTER_CT0="..."
TWITTER_PROXY=""  # Optional: http://user:pass@host:port
```

## Cron Setup

Agent loop runs every 60 seconds via OpenClaw isolated cron:
- Session: isolated (doesn't pollute main chat)
- Delivery: none (silent)
- Timeout: 120s

## Script I/O Convention

- **stdout** = structured JSON data
- **stderr** = status messages, logs
- Allows piping: `./scripts/portfolio.sh | jq '.eth_balance'`

## Common Base Addresses

| Token | Address |
|-------|---------|
| ETH (native) | `0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee` |
| WETH | `0x4200000000000000000000000000000000000006` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |

## Troubleshooting

- **"jq not found"** → `apt install jq`
- **"DexScreener rate limit"** → 300/min limit, agent retries next loop
- **"Swap failed"** → check ETH balance, token liquidity, slippage
- **"Twitter 407"** → proxy session expired, rotate `TWITTER_PROXY` session ID
- **"Twitter 226"** → rate limited (too many actions too fast), slow down
- **"Agent not responding"** → check SOUL.md exists, `.env` is configured
