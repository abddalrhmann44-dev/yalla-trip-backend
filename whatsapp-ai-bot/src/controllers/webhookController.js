'use strict';

/**
 * Webhook Controller — receives all WAAPI webhook events, routes them
 * to the correct handler, and always responds 200 immediately so WAAPI
 * doesn't retry.
 *
 * Expected WAAPI payload shape:
 * {
 *   "event": "message" | "message_ack" | "qr" | "ready" | "authenticated"
 *            | "auth_failure" | "disconnected" | "loading_screen",
 *   "instanceId": "...",
 *   "data": { ...event-specific fields... }
 * }
 */

const logger = require('../config/logger');
const messageHandler = require('../webhooks/handlers/messageHandler');
const statusHandler = require('../webhooks/handlers/statusHandler');
const instanceHandler = require('../webhooks/handlers/instanceHandler');

// Events that represent WhatsApp instance lifecycle changes
const INSTANCE_EVENTS = new Set([
  'qr', 'ready', 'authenticated', 'auth_failure',
  'disconnected', 'loading_screen',
]);

async function handleWebhook(req, res) {
  // Acknowledge immediately — WAAPI retries if we don't respond quickly
  res.status(200).json({ received: true });

  const { event, instanceId, data } = req.body || {};

  if (!event) {
    logger.warn('webhook_missing_event', { body: req.body });
    return;
  }

  logger.debug('webhook_event', { event, instanceId });

  try {
    if (event === 'message') {
      await messageHandler.handle(data || {});

    } else if (event === 'message_ack') {
      await statusHandler.handle(data || {});

    } else if (INSTANCE_EVENTS.has(event)) {
      await instanceHandler.handle(event, data || {});

    } else {
      logger.debug('webhook_event_unhandled', { event });
    }
  } catch (err) {
    // Log but never crash — the 200 is already sent
    logger.error('webhook_handler_error', { event, error: err.message, stack: err.stack });
  }
}

module.exports = { handleWebhook };
