'use strict';

const logger = require('../config/logger');
const { config } = require('../config');
const { WaapiError } = require('../services/waapiService');

// 404 — added after all routes
function notFound(req, res) {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
}

// Global error handler — 4-param signature required by Express
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // WaapiError: the upstream WAAPI call failed.
  // Map to 502 so callers know the error originated from the upstream service,
  // not from malformed input on their part.
  if (err instanceof WaapiError) {
    logger.error('waapi_upstream_error', {
      waapiStatus: err.statusCode,
      waapiBody: err.waapiBody,
      path: req.path,
      method: req.method,
      message: err.message,
    });

    return res.status(502).json({
      error: 'WAAPI_ERROR',
      message: err.message,
      waapiStatus: err.statusCode,
      ...(config.server.isProd ? {} : { waapiBody: err.waapiBody }),
    });
  }

  const status = err.status || 500;

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

  if (!config.server.isProd && err.stack) {
    body.stack = err.stack;
  }

  res.status(status).json(body);
}

module.exports = { notFound, errorHandler };
