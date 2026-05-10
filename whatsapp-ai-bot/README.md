# WhatsApp AI Bot

Production-ready WhatsApp AI bot powered by **WAAPI** (waapi.app) and **Anthropic Claude**. Handles inbound WhatsApp messages, maintains per-user conversation history, and replies with Claude-generated responses. Deployable to Railway in minutes.

## Features

- **AI replies** — Claude (claude-sonnet-4-6 by default) with full per-chat conversation memory
- **Typing simulation** — shows "typing…" indicator with proportional delay before sending
- **Message queue** — per-chat FIFO queue prevents out-of-order replies under rapid input
- **Conversation TTL** — configurable expiry and max-message cap per session
- **Webhook security** — constant-time secret comparison (`crypto.timingSafeEqual`)
- **Rate limiting** — separate limits for API and webhook endpoints
- **Structured logging** — JSON in production, colorized in development, daily log rotation
- **Graceful shutdown** — drains connections on SIGTERM/SIGINT
- **Reset command** — user sends `!reset` to clear their conversation history

---

## Project Structure

```
whatsapp-ai-bot/
├── src/
│   ├── app.js                        # Express app entry point
│   ├── config/
│   │   ├── index.js                  # Config object + validation
│   │   └── logger.js                 # Winston logger
│   ├── controllers/
│   │   ├── instanceController.js     # WAAPI instance management + /health
│   │   ├── messageController.js      # Send text / media / get history
│   │   └── webhookController.js      # Webhook router
│   ├── middlewares/
│   │   ├── authMiddleware.js         # Webhook secret validation
│   │   ├── errorMiddleware.js        # 404 + global error handler
│   │   ├── rateLimiter.js            # API + webhook rate limits
│   │   └── requestLogger.js          # Per-request logging
│   ├── routes/
│   │   ├── index.js
│   │   ├── instanceRoutes.js
│   │   ├── messageRoutes.js
│   │   └── webhookRoutes.js
│   ├── services/
│   │   ├── claudeService.js          # Anthropic SDK wrapper
│   │   ├── conversationService.js    # In-memory history store with TTL
│   │   ├── messageQueue.js           # Per-chat Promise-chain queue
│   │   └── waapiService.js           # WAAPI HTTP client (axios + retry)
│   ├── utils/
│   │   ├── delay.js                  # Random delay helper
│   │   ├── phoneUtils.js             # E.164 ↔ chatId conversion
│   │   └── retry.js                  # Generic retry utility
│   └── webhooks/handlers/
│       ├── instanceHandler.js        # QR / ready / disconnect events
│       ├── messageHandler.js         # Inbound message processing
│       └── statusHandler.js          # message_ack events
├── .env.example
├── .gitignore
├── Dockerfile
├── package.json
└── railway.json
```

---

## Quick Start (Local)

### Prerequisites

- Node.js ≥ 18
- A [waapi.app](https://waapi.app) account with an active instance
- An [Anthropic](https://console.anthropic.com) API key
- A publicly reachable URL for the webhook (e.g. via [ngrok](https://ngrok.com))

### 1. Clone and install

```bash
git clone https://github.com/<your-org>/whatsapp-ai-bot.git
cd whatsapp-ai-bot
npm install
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` with your credentials (see [Environment Variables](#environment-variables)).

### 3. Expose local server

```bash
npx ngrok http 3000
# Copy the https URL, e.g. https://abc123.ngrok.io
```

### 4. Configure WAAPI webhook

In your [waapi.app](https://waapi.app) dashboard:

1. Go to **Webhook Settings**
2. Set Webhook URL to `https://abc123.ngrok.io/webhook`
3. Set the Webhook Secret to the same value as `WEBHOOK_SECRET` in your `.env`
4. Save and enable

### 5. Run

```bash
npm run dev   # development (nodemon + colorized logs)
npm start     # production
```

---

## Deploying to Railway

### 1. Push your repo to GitHub

```bash
git add .
git commit -m "feat: whatsapp-ai-bot initial release"
git push origin main
```

### 2. Create Railway project

1. Go to [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo**
2. Select this repository
3. Railway detects the `Dockerfile` and `railway.json` automatically

### 3. Set environment variables

In the Railway project → **Variables** tab, add all required variables:

| Variable | Value |
|---|---|
| `WAAPI_API_KEY` | Your WAAPI Bearer token |
| `WAAPI_INSTANCE_ID` | Your WAAPI instance ID |
| `ANTHROPIC_API_KEY` | Your Anthropic API key |
| `WEBHOOK_SECRET` | A strong random string |
| `NODE_ENV` | `production` |

### 4. Get your Railway URL

After first deploy: **Settings** → **Domains** → copy the generated URL (e.g. `https://whatsapp-ai-bot.up.railway.app`).

### 5. Update WAAPI webhook

Set the webhook URL in your waapi.app dashboard to:

```
https://whatsapp-ai-bot.up.railway.app/webhook
```

### 6. Connect your WhatsApp

```bash
# Scan QR via API
curl https://whatsapp-ai-bot.up.railway.app/api/instance/qr \
  -H "Authorization: Bearer <your-api-key>"
```

Or use the instance management endpoints documented below.

---

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `PORT` | No | `3000` | HTTP server port |
| `NODE_ENV` | No | `development` | `development` or `production` |
| `WAAPI_BASE_URL` | No | `https://waapi.app/api/v1` | WAAPI base URL |
| `WAAPI_API_KEY` | **Yes** | — | WAAPI Bearer token from dashboard |
| `WAAPI_INSTANCE_ID` | **Yes** | — | WAAPI instance ID |
| `ANTHROPIC_API_KEY` | **Yes** | — | Anthropic Console API key |
| `CLAUDE_MODEL` | No | `claude-sonnet-4-6` | Claude model ID |
| `CLAUDE_MAX_TOKENS` | No | `1024` | Max tokens per response |
| `WEBHOOK_SECRET` | **Yes** | — | Shared secret for webhook validation |
| `IGNORE_GROUPS` | No | `true` | Drop group messages |
| `IGNORE_STATUS` | No | `true` | Drop broadcast/status messages |
| `TYPING_DELAY_MIN` | No | `1000` | Min typing delay (ms) |
| `TYPING_DELAY_MAX` | No | `3000` | Max typing delay (ms) |
| `CONVERSATION_TTL_MINUTES` | No | `60` | Conversation expiry (0 = never) |
| `CONVERSATION_MAX_MESSAGES` | No | `20` | Max stored messages per chat |
| `RATE_LIMIT_WINDOW_MS` | No | `60000` | Rate limit window (ms) |
| `RATE_LIMIT_MAX_REQUESTS` | No | `100` | Max API requests per window |
| `BOT_SYSTEM_PROMPT` | No | built-in | Override Claude system prompt |

---

## API Reference

All REST endpoints are under `/api` and rate-limited to 100 req/min.

### Health

```
GET /health
```

Response:
```json
{
  "status": "ok",
  "uptime": 3620.5,
  "memory": { "rss": 45678592, "heapUsed": 23456789 },
  "activeSessions": 3,
  "activeQueues": 1
}
```

### Instance

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/instance/status` | Connection status |
| `GET` | `/api/instance/qr` | Get QR code for scanning |
| `POST` | `/api/instance/connect` | Initiate connection |
| `POST` | `/api/instance/disconnect` | Disconnect instance |
| `POST` | `/api/instance/restart` | Restart instance |
| `GET` | `/api/instance/chats` | List all chats |

#### GET /api/instance/status

```bash
curl https://your-bot.up.railway.app/api/instance/status
```

```json
{
  "instanceId": "12345",
  "status": "connected",
  "authenticated": true
}
```

### Messages

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/messages/send` | Send text message |
| `POST` | `/api/messages/send-media` | Send image / video / document |
| `GET` | `/api/messages/:phone` | Get chat history |

#### POST /api/messages/send

```bash
curl -X POST https://your-bot.up.railway.app/api/messages/send \
  -H "Content-Type: application/json" \
  -d '{"phone": "+966501234567", "message": "Hello from the bot!"}'
```

```json
{ "success": true, "messageId": "msg_abc123" }
```

#### POST /api/messages/send-media

```bash
curl -X POST https://your-bot.up.railway.app/api/messages/send-media \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+966501234567",
    "mediaUrl": "https://example.com/image.jpg",
    "caption": "Check this out",
    "mediaType": "image"
  }'
```

#### GET /api/messages/:phone

```bash
curl https://your-bot.up.railway.app/api/messages/966501234567
```

---

## Webhook

WAAPI posts all WhatsApp events to `POST /webhook`.

The endpoint validates the `x-waapi-secret` header before processing.

### Inbound Message Payload

```json
{
  "event": "message",
  "instanceId": "12345",
  "data": {
    "id": "msg_xyz789",
    "from": "966501234567@c.us",
    "body": "Hello! What can you do?",
    "type": "chat",
    "timestamp": 1715000000,
    "fromMe": false,
    "isGroupMsg": false
  }
}
```

### Instance Event Payload

```json
{
  "event": "qr",
  "instanceId": "12345",
  "data": { "qr": "data:image/png;base64,..." }
}
```

Supported instance events: `qr`, `ready`, `authenticated`, `auth_failure`, `disconnected`, `loading_screen`.

On `disconnected` (unless reason is `LOGOUT`), the bot automatically attempts to reconnect after 10 seconds.

---

## Claude Integration Flow

```
User sends WhatsApp message
        │
        ▼
POST /webhook (WAAPI → Bot)
        │
  Validate secret
        │
  Filter groups / status / fromMe
        │
  Enqueue in per-chat queue
        │
  Mark message as read (✓✓)
  Send "typing…" indicator
        │
  Fetch conversation history
  Append user message
        │
  Call Claude API with full history + system prompt
        │
  Append assistant reply to history
  Random delay (proportional to reply length)
  Stop typing indicator
        │
  Send reply via WAAPI sendTextMessage
        │
User receives AI reply
```

### Reset Command

A user can send `!reset` to clear their conversation history and start fresh. The bot replies with a confirmation message.

---

## Customising the System Prompt

Set `BOT_SYSTEM_PROMPT` in your environment:

```
BOT_SYSTEM_PROMPT=You are Aria, a friendly customer support agent for Yalla Trip. Answer only travel-related questions in Arabic and English. Be concise and helpful.
```

Or edit the default directly in [src/services/claudeService.js](src/services/claudeService.js).

---

## Logs

In **development**: colorized, human-readable output to stdout.

In **production**: JSON lines to stdout + rotating daily files in `logs/`:
- `logs/app-YYYY-MM-DD.log` — all levels
- `logs/error-YYYY-MM-DD.log` — errors only
- Files rotate daily, kept for 14 days, compressed with gzip after 1 day

Key log events:

| Event | Level | Meaning |
|---|---|---|
| `server_started` | info | App is listening |
| `webhook_received` | debug | Raw webhook payload |
| `message_received` | info | Inbound user message |
| `claude_response` | info | AI reply generated |
| `message_sent` | info | Reply delivered |
| `instance_event` | info | QR/ready/disconnect etc. |
| `shutdown_signal` | info | SIGTERM/SIGINT received |

---

## Security Notes

- Webhook secret validated with `crypto.timingSafeEqual` to prevent timing attacks
- Helmet sets secure HTTP headers
- Rate limiting on all endpoints
- Non-root Docker user (`appuser`)
- Secrets never logged — only presence/absence is checked at startup
- Stack traces hidden from API error responses in production

---

## License

MIT
