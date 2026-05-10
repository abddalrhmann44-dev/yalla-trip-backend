'use strict';

const morgan = require('morgan');
const logger = require('../config/logger');
const { config } = require('../config');

// Stream morgan output through our Winston logger
const stream = {
  write: (message) => logger.http(message.trim()),
};

const requestLogger = morgan(
  config.server.isProd ? 'combined' : 'dev',
  { stream }
);

module.exports = { requestLogger };
