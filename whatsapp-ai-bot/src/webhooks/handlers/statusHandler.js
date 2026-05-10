'use strict';

/**
 * Handles WhatsApp message delivery status updates
 * (sent → delivered → read) from the WAAPI webhook.
 */

const logger = require('../../config/logger');

async function handle(data) {
  const { id, from, status, timestamp } = data;

  logger.debug('msg_status_update', {
    messageId: id,
    from,
    status,
    timestamp,
  });

  // Add custom logic here: e.g. update a DB record, trigger analytics, etc.
}

module.exports = { handle };
