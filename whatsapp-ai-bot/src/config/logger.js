'use strict';

const { createLogger, format, transports } = require('winston');
require('winston-daily-rotate-file');
const { config } = require('./index');

const { combine, timestamp, colorize, printf, json, errors } = format;

// Human-readable format for development
const devFormat = combine(
  colorize(),
  timestamp({ format: 'HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp, stack, ...meta }) => {
    const metaStr = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
    return `[${timestamp}] ${level}: ${stack || message}${metaStr}`;
  })
);

// Structured JSON for production (Railway log aggregation)
const prodFormat = combine(
  timestamp(),
  errors({ stack: true }),
  json()
);

const logger = createLogger({
  level: config.server.isProd ? 'info' : 'debug',
  format: config.server.isProd ? prodFormat : devFormat,
  transports: [
    new transports.Console(),
    // Rotate daily log files in production
    ...(config.server.isProd
      ? [
          new transports.DailyRotateFile({
            filename: 'logs/app-%DATE%.log',
            datePattern: 'YYYY-MM-DD',
            maxFiles: '14d',
            zippedArchive: true,
          }),
          new transports.DailyRotateFile({
            filename: 'logs/error-%DATE%.log',
            datePattern: 'YYYY-MM-DD',
            level: 'error',
            maxFiles: '30d',
            zippedArchive: true,
          }),
        ]
      : []),
  ],
});

module.exports = logger;
