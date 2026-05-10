'use strict';

/**
 * Webhook authentication middleware.
 *
 * WAAPI sends an `x-waapi-secret` header (or query param `secret`)
 * containing the webhook secret you configured in the dashboard.
 * We do a constant-time comparison to prevent timing attacks.
 */

const crypto = require('crypto');
const { config } = require('../config');
const logger = require('../config/logger');

function validateWebhook(req, res, next) {
  const provided =
    req.headers['x-waapi-secret'] ||
    req.headers['x-webhook-secret'] ||
    req.query.secret ||
    '';

  const expected = config.webhook.secret;

  // Constant-time compare to prevent timing attacks
  const valid =
    provided.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(expected));

  if (!valid) {
    logger.warn('webhook_auth_failed', {
      ip: req.ip,
      path: req.path,
    });
    return res.status(401).json({ error: 'Unauthorized' });
  }

  next();
}

module.exports = { validateWebhook };
