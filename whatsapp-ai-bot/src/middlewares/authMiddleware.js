'use strict';

/**
 * Webhook authentication middleware.
 *
 * WAAPI sends an `x-waapi-secret` header containing the webhook secret
 * you configured in the dashboard.
 *
 * Security: we always run crypto.timingSafeEqual on fixed-size buffers
 * regardless of input length, preventing secret-length disclosure via
 * timing side-channels.
 */

const crypto = require('crypto');
const { config } = require('../config');
const logger = require('../config/logger');

// Fixed comparison buffer size — must be ≥ max expected secret length.
const CMP_SIZE = 256;

function validateWebhook(req, res, next) {
  const provided =
    req.headers['x-waapi-secret'] ||
    req.headers['x-webhook-secret'] ||
    req.query.secret ||
    '';

  const expected = config.webhook.secret;

  // Always allocate fixed-size buffers so timingSafeEqual runs in constant
  // time even when lengths differ — prevents secret-length timing leak.
  const a = Buffer.alloc(CMP_SIZE, 0);
  const b = Buffer.alloc(CMP_SIZE, 0);
  a.write(provided.slice(0, CMP_SIZE));
  b.write(expected.slice(0, CMP_SIZE));

  // timingSafeEqual result alone is not enough — we must also check the
  // actual lengths to prevent a truncation bypass (a short secret matching
  // the first N bytes of a long one after zero-padding).
  const valid = crypto.timingSafeEqual(a, b) && provided.length === expected.length;

  if (!valid) {
    logger.warn('webhook_auth_failed', { ip: req.ip, path: req.path });
    return res.status(401).json({ error: 'Unauthorized' });
  }

  next();
}

module.exports = { validateWebhook };
