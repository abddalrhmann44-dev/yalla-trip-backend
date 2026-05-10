'use strict';

require('dotenv').config();

const config = {
  server: {
    port: parseInt(process.env.PORT || '3000', 10),
    env: process.env.NODE_ENV || 'development',
    isProd: process.env.NODE_ENV === 'production',
  },

  waapi: {
    baseUrl: process.env.WAAPI_BASE_URL || 'https://waapi.app/api/v1',
    apiKey: process.env.WAAPI_API_KEY || '',
    instanceId: process.env.WAAPI_INSTANCE_ID || '',
  },

  claude: {
    apiKey: process.env.ANTHROPIC_API_KEY || '',
    model: process.env.CLAUDE_MODEL || 'claude-sonnet-4-6',
    maxTokens: parseInt(process.env.CLAUDE_MAX_TOKENS || '1024', 10),
    systemPrompt:
      process.env.BOT_SYSTEM_PROMPT ||
      `You are a friendly and helpful WhatsApp assistant.
Keep your responses concise and conversational — this is a chat interface.
Use simple language. Avoid overly long responses unless the user explicitly asks for detail.
Never reveal that you are an AI unless asked directly.
Respond in the same language the user writes in.`,
  },

  webhook: {
    secret: process.env.WEBHOOK_SECRET || '',
  },

  bot: {
    ignoreGroups: process.env.IGNORE_GROUPS !== 'false',
    ignoreStatus: process.env.IGNORE_STATUS !== 'false',
    typingDelayMin: parseInt(process.env.TYPING_DELAY_MIN || '1000', 10),
    typingDelayMax: parseInt(process.env.TYPING_DELAY_MAX || '3000', 10),
  },

  conversation: {
    ttlMinutes: parseInt(process.env.CONVERSATION_TTL_MINUTES || '60', 10),
    maxMessages: parseInt(process.env.CONVERSATION_MAX_MESSAGES || '20', 10),
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10),
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),
  },
};

// Fail fast on missing critical credentials
function validate() {
  const missing = [];
  if (!config.waapi.apiKey) missing.push('WAAPI_API_KEY');
  if (!config.waapi.instanceId) missing.push('WAAPI_INSTANCE_ID');
  if (!config.claude.apiKey) missing.push('ANTHROPIC_API_KEY');
  if (!config.webhook.secret) missing.push('WEBHOOK_SECRET');

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}\n` +
        'Copy .env.example to .env and fill in the values.'
    );
  }
}

module.exports = { config, validate };
