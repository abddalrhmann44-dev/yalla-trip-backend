'use strict';

/**
 * In-memory conversation store with TTL and max-message cap.
 * Each key is a chatId; value is { messages: [], lastActivity: Date }.
 *
 * For multi-process or persistent deployments replace the Map with
 * Redis (ioredis) — the public API stays identical.
 */

const { config } = require('../config');
const logger = require('../config/logger');

const store = new Map();

// Sweep expired conversations every 5 minutes
const SWEEP_INTERVAL_MS = 5 * 60 * 1_000;

function ttlMs() {
  const min = config.conversation.ttlMinutes;
  return min > 0 ? min * 60 * 1_000 : Infinity;
}

setInterval(() => {
  const now = Date.now();
  const limit = ttlMs();
  if (limit === Infinity) return;

  let removed = 0;
  for (const [chatId, session] of store.entries()) {
    if (now - session.lastActivity > limit) {
      store.delete(chatId);
      removed++;
    }
  }
  if (removed > 0) logger.debug('conversation_sweep', { removed });
}, SWEEP_INTERVAL_MS).unref(); // .unref() so the timer doesn't block process exit

// ---------- Public API ----------

/**
 * Return the message history for Claude (array of {role, content}).
 */
function getHistory(chatId) {
  const session = store.get(chatId);
  if (!session) return [];
  // Touch last activity
  session.lastActivity = Date.now();
  return session.messages;
}

/**
 * Append a user or assistant message to the conversation.
 * @param {string} chatId
 * @param {'user'|'assistant'} role
 * @param {string} content
 */
function addMessage(chatId, role, content) {
  if (!store.has(chatId)) {
    store.set(chatId, { messages: [], lastActivity: Date.now() });
  }

  const session = store.get(chatId);
  session.messages.push({ role, content });
  session.lastActivity = Date.now();

  // Trim oldest messages keeping the cap (preserve pairs for context)
  const max = config.conversation.maxMessages;
  if (session.messages.length > max) {
    session.messages = session.messages.slice(session.messages.length - max);
  }
}

/**
 * Clear all history for a chat (e.g. user types "reset").
 */
function clearHistory(chatId) {
  store.delete(chatId);
  logger.info('conversation_cleared', { chatId });
}

/**
 * Total active sessions (useful for health endpoint).
 */
function activeSessions() {
  return store.size;
}

module.exports = { getHistory, addMessage, clearHistory, activeSessions };
