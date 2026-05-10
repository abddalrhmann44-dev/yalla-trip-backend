'use strict';

const logger = require('../config/logger');

/**
 * Retry an async function up to `maxAttempts` times with exponential back-off.
 *
 * @param {Function} fn           - async function to retry
 * @param {object}   opts
 * @param {number}   opts.maxAttempts  - default 3
 * @param {number}   opts.baseDelayMs  - initial delay in ms, default 500
 * @param {string}   opts.label        - log label
 */
async function withRetry(fn, { maxAttempts = 3, baseDelayMs = 500, label = 'retry' } = {}) {
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (attempt < maxAttempts) {
        const delay = baseDelayMs * 2 ** (attempt - 1);
        logger.warn(`${label}_retry`, { attempt, maxAttempts, delayMs: delay, error: err.message });
        await new Promise((r) => setTimeout(r, delay));
      }
    }
  }

  throw lastError;
}

module.exports = { withRetry };
