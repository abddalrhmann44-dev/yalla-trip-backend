'use strict';

const logger = require('../config/logger');
const { config } = require('../config');

// 404 handler — must be added after all routes
function notFound(req, res) {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
}

// Global error handler — must have 4 params for Express to treat as error middleware
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const status = err.status || err.statusCode || 500;

  logger.error('unhandled_error', {
    status,
    message: err.message,
    path: req.path,
    method: req.method,
    stack: config.server.isProd ? undefined : err.stack,
  });

  const body = {
    error: status < 500 ? err.message : 'Internal server error',
  };

  // Expose stack in dev for easier debugging
  if (!config.server.isProd && err.stack) {
    body.stack = err.stack;
  }

  res.status(status).json(body);
}

module.exports = { notFound, errorHandler };
