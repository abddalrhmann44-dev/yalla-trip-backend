'use strict';

/**
 * Handles WAAPI instance lifecycle events:
 * qr, ready, authenticated, auth_failure, disconnected, loading_screen.
 */

const logger = require('../../config/logger');
const waapiService = require('../../services/waapiService');

// How long to wait before attempting auto-reconnect (ms)
const RECONNECT_DELAY_MS = 10_000;

async function handle(event, data) {
  switch (event) {
    case 'qr':
      logger.info('instance_qr_ready', { hint: 'Scan the QR code in your dashboard' });
      break;

    case 'ready':
    case 'authenticated':
      logger.info('instance_connected', { event });
      break;

    case 'auth_failure':
      logger.error('instance_auth_failure', { data });
      // Auth failures usually need a fresh QR scan — don't auto-reconnect
      break;

    case 'disconnected': {
      const reason = data?.reason || 'unknown';
      logger.warn('instance_disconnected', { reason });

      if (reason !== 'LOGOUT') {
        logger.info('instance_reconnect_scheduled', { delayMs: RECONNECT_DELAY_MS });
        setTimeout(async () => {
          try {
            await waapiService.restartInstance();
            logger.info('instance_reconnect_success');
          } catch (err) {
            logger.error('instance_reconnect_failed', { error: err.message });
          }
        }, RECONNECT_DELAY_MS);
      }
      break;
    }

    case 'loading_screen':
      logger.debug('instance_loading', { percent: data?.percent });
      break;

    default:
      logger.debug('instance_event_unknown', { event, data });
  }
}

module.exports = { handle };
