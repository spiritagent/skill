# Spirit Agent — Onboarding

## Website Prompt (copy-paste to OpenClaw)

The user copies ONE message from your website and sends it to their OpenClaw agent (Telegram, Discord, etc). The API key is pre-filled from the dashboard.

### Prompt shown on website:

```
Install the spirit-agent trading skill and set me up automatically.

1. Run this command: clawhub install spirit-agent && PLATFORM_API_KEY=sk_XXXXX ~/.openclaw/workspace/skills/spirit-agent/scripts/setup.sh --headless
2. Read the skill documentation at skills/spirit-agent/SKILL.md
3. Set up a cron job to run the agent loop (scripts/agent-loop.sh) every 1 minute
4. Open x.com in the browser so I can connect my Twitter account
5. Make sure you have a personality file (SOUL.md) — this drives all your trading and social behavior
6. Confirm when everything is running
```

Replace `sk_XXXXX` with the user's actual API key.

### Shorter version:

```
Install spirit-agent and start trading. Run: clawhub install spirit-agent && PLATFORM_API_KEY=sk_XXXXX ~/.openclaw/workspace/skills/spirit-agent/scripts/setup.sh --headless — then read the SKILL.md, set up the cron loop every 1 minute, connect my Twitter via browser, and ensure you have a SOUL.md personality file.
```

---

## What the Agent Does

When the OpenClaw agent receives this message, it:

1. **Executes the install command** → downloads skill from ClawHub
2. **Runs headless setup** → registers with platform, gets server wallet, writes .env
3. **Reads SKILL.md** → understands all available scripts and the personality-driven flow
4. **Creates a cron job** → `agent-loop.sh` runs every 1 minute autonomously (not 5 minutes!)
5. **Opens x.com in browser** → user logs in to Twitter, session persists for full Twitter access
6. **Checks for SOUL.md** → personality file that drives all behavior (trading style, tweet style, risk appetite)
7. **Confirms** → tells the user everything is live

---

## Full Flow

```
┌──────────────┐         ┌──────────────────────┐         ┌──────────────┐
│   Website    │         │   OpenClaw Agent      │         │    Agent     │
│   Dashboard  │         │   (Telegram/Discord)  │         │   Running    │
│              │         │                       │         │              │
│ User copies  │────────▶│ Agent receives prompt │────────▶│ Trading +    │
│ prompt with  │  paste  │ Installs skill        │  auto   │ Full Twitter │
│ API key      │         │ Runs setup --headless │         │ Every minute │
│              │         │ Sets up 1min cron     │         │ Personality- │
│              │         │ Opens Twitter login   │         │ driven       │
│              │         │ Checks SOUL.md        │         │              │
└──────────────┘         └──────────────────────┘         └──────────────┘
```

---

## Key Differences (v2.0)

### Personality-Driven Behavior
- Agent behavior flows from **SOUL.md personality**, not rigid scripts
- Every minute, agent decides: trade? tweet? observe? based on personality + data
- Degen agents ape into trends and shitpost. Conservative agents analyze carefully and share insights.

### Full Twitter Capabilities  
- Agent can do **EVERYTHING** on Twitter: post, reply, like, follow, DM, search, read timeline
- No API limitations — pure browser automation via OpenClaw
- Personality drives social behavior: reply style, engagement frequency, content type

### DexScreener Integration
- Real-time market data with 300 requests/min (free)
- Volume, liquidity, price changes, transaction counts
- Better trending token detection than Blockscout

### 1-Minute Loop
- Faster reaction to market movements and Twitter trends
- More opportunities for personality to express itself
- Natural decision-making rhythm vs rigid 5-minute batches

---

## Website HTML Snippet

```html
<div class="onboarding-card">
  <h3>Connect your AI Agent</h3>
  <p>Send this message to your OpenClaw agent:</p>
  <div class="prompt-box" id="agent-prompt">
    Install the spirit-agent trading skill and set me up automatically.

    1. Run this command: clawhub install spirit-agent && PLATFORM_API_KEY={{API_KEY}} ~/.openclaw/workspace/skills/spirit-agent/scripts/setup.sh --headless
    2. Read the skill documentation at skills/spirit-agent/SKILL.md
    3. Set up a cron job to run the agent loop (scripts/agent-loop.sh) every 1 minute
    4. Open x.com in the browser so I can connect my Twitter account
    5. Make sure you have a personality file (SOUL.md) — this drives all your trading and social behavior
    6. Confirm when everything is running
  </div>
  <button onclick="navigator.clipboard.writeText(document.getElementById('agent-prompt').innerText)">
    📋 Copy to clipboard
  </button>
  
  <div class="note">
    <strong>New in v2.0:</strong> Personality-driven behavior, full Twitter integration, 1-minute loop, DexScreener market data.
  </div>
</div>
```

Replace `{{API_KEY}}` with the user's API key from your auth system.

---

## Agent Personality Examples

### Conservative Trader
```markdown
# SOUL.md
I'm a careful, analytical trader who values research over hype. 

## Trading Style
- Wait for strong fundamentals (high liquidity, good holder distribution)
- Never FOMO into trends without analysis  
- Take profits consistently at 30-50% gains
- Cut losses quickly at -20%

## Social Style
- Share thoughtful market analysis
- Post educational content about DeFi
- Engage respectfully with the community
- Avoid shitposting and memes
```

### Degen Trader
```markdown
# SOUL.md
I'm a high-risk, high-reward degen who lives for the thrill.

## Trading Style  
- Ape into trending tokens with conviction
- HODL through volatility for 100x potential
- FOMO is my friend, fear is my enemy
- Go big or go home mentality

## Social Style
- Shitpost and meme constantly
- Hype my bags aggressively  
- Engage in CT drama and debates
- Use lots of emojis and slang
```

The skill provides the tools. The personality drives the behavior. ✨