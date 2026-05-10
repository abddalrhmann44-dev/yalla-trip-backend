'use strict';

/**
 * Request validation middleware for message endpoints.
 * Validates and normalises inputs before they reach controllers or services.
 */

const { formatChatId } = require('../utils/phoneUtils');

const VALID_MEDIA_TYPES = new Set(['image', 'video', 'document', 'audio']);
const MAX_MESSAGE_LENGTH = 4096;

/**
 * Validate POST /api/messages/send
 * Required: phone (string), message (string)
 */
function validateSendText(req, res, next) {
  const { phone, message } = req.body || {};

  if (!phone || typeof phone !== 'string' || !phone.trim()) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      field: 'phone',
      message: '"phone" is required and must be a non-empty string.',
    });
  }

  if (!message || typeof message !== 'string' || !message.trim()) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      field: 'message',
      message: '"message" is required and must be a non-empty string.',
    });
  }

  if (message.length > MAX_MESSAGE_LENGTH) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      field: 'message',
      message: `"message" must not exceed ${MAX_MESSAGE_LENGTH} characters (got ${message.length}).`,
    });
  }

  // Validate + normalise the phone number now so the error surfaces here,
  // not deep in the service layer.
  try {
    formatChatId(phone.trim());
  } catch (err) {
    return res.status(400).json({
      error: 'INVALID_PHONE',
      field: 'phone',
      message: err.message,
      examples: ['+201012345678', '201012345678', '01012345678', '+966501234567'],
    });
  }

  next();
}

/**
 * Validate POST /api/messages/send-media
 * Required: phone (string), mediaUrl (string)
 * Optional: mediaType ("image"|"video"|"document"|"audio"), caption, fileName
 */
function validateSendMedia(req, res, next) {
  const { phone, mediaUrl, mediaType } = req.body || {};

  if (!phone || typeof phone !== 'string' || !phone.trim()) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      field: 'phone',
      message: '"phone" is required and must be a non-empty string.',
    });
  }

  if (!mediaUrl || typeof mediaUrl !== 'string' || !mediaUrl.trim()) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      field: 'mediaUrl',
      message: '"mediaUrl" is required and must be a non-empty string.',
    });
  }

  if (mediaType !== undefined && !VALID_MEDIA_TYPES.has(mediaType)) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      field: 'mediaType',
      message: `"mediaType" must be one of: ${[...VALID_MEDIA_TYPES].join(', ')}.`,
    });
  }

  try {
    formatChatId(phone.trim());
  } catch (err) {
    return res.status(400).json({
      error: 'INVALID_PHONE',
      field: 'phone',
      message: err.message,
      examples: ['+201012345678', '201012345678', '01012345678', '+966501234567'],
    });
  }

  next();
}

/**
 * Validate GET /api/messages/:phone
 * Normalises :phone so the controller always receives a valid chatId.
 */
function validateGetMessages(req, res, next) {
  const { phone } = req.params;

  if (!phone || !phone.trim()) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      field: 'phone',
      message: 'Phone number is required in the URL path.',
    });
  }

  try {
    formatChatId(phone.trim());
  } catch (err) {
    return res.status(400).json({
      error: 'INVALID_PHONE',
      field: 'phone',
      message: err.message,
    });
  }

  next();
}

module.exports = { validateSendText, validateSendMedia, validateGetMessages };
