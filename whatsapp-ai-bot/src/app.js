'use strict';

// Load and validate config before anything else
const { config, validate } = require('./config');
validate();

const express = require('express');
const helmet = require('helmet');

const logger = require('./config/logger');
const { requestLogger } = require('./middlewares/requestLogger');
const { apiLimiter } = require('./middlewares/rateLimiter');
const { notFound, errorHandler } = require('./middlewares/errorMiddleware');

const apiRoutes = require('./routes');
const webhookRoutes = require('./routes/webhookRoutes');
const instanceController = require('./controllers/instanceController');

const app = express();

// ── Security headers ──────────────────────────────────────────
app.set('trust proxy', 1); // Required when behind Railway's proxy
app.use(helmet());

// ── Request parsing ───────────────────────────────────────────
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Logging ───────────────────────────────────────────────────
app.use(requestLogger);

// ── Routes ────────────────────────────────────────────────────

// Health check (no auth, no rate-limit — used by Railway)
app.get('/health', instanceController.health);

// Webhook endpoint (has its own auth + rate-limit middleware)
app.use('/webhook', webhookRoutes);

// REST API (global rate limiter)
app.use('/api', apiLimiter, apiRoutes);

// ── Error handling ────────────────────────────────────────────
app.use(notFound);
app.use(errorHandler);

// ── Start ─────────────────────────────────────────────────────
const server = app.listen(config.server.port, () => {
  logger.info('server_started', {
    port: config.server.port,
    env: config.server.env,
    instanceId: config.waapi.instanceId,
  });
});

// ── Graceful shutdown ─────────────────────────────────────────
function shutdown(signal) {
  logger.info('shutdown_signal', { signal });
  server.close(() => {
    logger.info('server_closed');
    process.exit(0);
  });

  // Force exit if server doesn't close in time
  setTimeout(() => {
    logger.error('shutdown_forced');
    process.exit(1);
  }, 10_000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('uncaughtException', (err) => {
  logger.error('uncaught_exception', { error: err.message, stack: err.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.error('unhandled_rejection', { reason: String(reason) });
});

module.exports = app; // for testing
