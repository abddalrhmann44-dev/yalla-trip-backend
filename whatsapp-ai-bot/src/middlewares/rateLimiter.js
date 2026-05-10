'use strict';

const rateLimit = require('express-rate-limit');
const { config } = require('../config');
const logger = require('../config/logger');

// General API rate limiter
const apiLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('rate_limit_hit', { ip: req.ip, path: req.path });
    res.status(429).json({ error: 'Too many requests. Please slow down.' });
  },
});

// Stricter limiter for the webhook endpoint (prevent webhook flood)
const webhookLimiter = rateLimit({
  windowMs: 60_000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('webhook_rate_limit_hit', { ip: req.ip });
    res.status(429).json({ error: 'Too many webhook events.' });
  },
});

module.exports = { apiLimiter, webhookLimiter };
