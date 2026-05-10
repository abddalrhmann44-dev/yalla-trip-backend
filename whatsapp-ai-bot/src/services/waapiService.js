'use strict';

/**
 * WAAPI Service — all communication with waapi.app REST API.
 * Docs: https://waapi.readme.io/reference/waapi-api-documentation
 */

const axios = require('axios');
const axiosRetry = require('axios-retry').default;
const { config } = require('../config');
const logger = require('../config/logger');

// ── Custom error class ────────────────────────────────────────────

class WaapiError extends Error {
  /**
   * @param {string} message
   * @param {number|undefined} statusCode  HTTP status from WAAPI
   * @param {any}   waapiBody              Raw WAAPI response body
   */
  constructor(message, statusCode, waapiBody) {
    super(message);
    this.name = 'WaapiError';
    this.statusCode = statusCode;
    this.waapiBody = waapiBody;
  }
}

// ── HTTP client ───────────────────────────────────────────────────

const http = axios.create({
  baseURL: config.waapi.baseUrl,
  timeout: 30_000,
  headers: {
    Authorization: `Bearer ${config.waapi.apiKey}`,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
});

// Retry on network errors and 5xx — never retry 4xx (client errors)
axiosRetry(http, {
  retries: 3,
  retryDelay: axiosRetry.exponentialDelay,
  retryCondition: (err) =>
    axiosRetry.isNetworkError(err) ||
    (err.response && err.response.status >= 500),
  onRetry: (retryCount, err) => {
    logger.warn('waapi_retry', {
      attempt: retryCount,
      url: err.config?.url,
      status: err.response?.status,
      error: err.message,
    });
  },
});

// ── Helpers ───────────────────────────────────────────────────────

function instancePath(path = '') {
  return `/instances/${config.waapi.instanceId}${path}`;
}

function extractData(response) {
  return response.data;
}

/**
 * Parse a WAAPI error response into a human-readable message.
 * WAAPI wraps errors differently across endpoints — this covers the common shapes.
 */
function waapiErrorMessage(responseData) {
  if (!responseData) return 'Unknown WAAPI error';
  if (typeof responseData === 'string') return responseData;
  return (
    responseData.message ||
    responseData.error ||
    responseData.detail ||
    JSON.stringify(responseData)
  );
}

/**
 * Wrap an axios error into a WaapiError with structured logging.
 * Always throws.
 */
function handleAxiosError(err, context) {
  const status = err.response?.status;
  const body = err.response?.data;

  logger.error('waapi_request_failed', {
    ...context,
    httpStatus: status,
    waapiResponse: body,
    error: err.message,
  });

  throw new WaapiError(
    `WAAPI [${status ?? 'NETWORK'}] ${waapiErrorMessage(body)}`,
    status,
    body
  );
}

// ── Instance management ───────────────────────────────────────────

async function getInstanceStatus() {
  try {
    const res = await http.get(instancePath());
    return extractData(res);
  } catch (err) {
    handleAxiosError(err, { action: 'getInstanceStatus' });
  }
}

async function connectInstance() {
  try {
    const res = await http.post(instancePath('/client/action/start-session'));
    return extractData(res);
  } catch (err) {
    handleAxiosError(err, { action: 'connectInstance' });
  }
}

async function disconnectInstance() {
  try {
    const res = await http.post(instancePath('/client/action/logout'));
    return extractData(res);
  } catch (err) {
    handleAxiosError(err, { action: 'disconnectInstance' });
  }
}

async function getQRCode() {
  try {
    const res = await http.get(instancePath('/client/qr'));
    return extractData(res);
  } catch (err) {
    handleAxiosError(err, { action: 'getQRCode' });
  }
}

async function restartInstance() {
  logger.info('waapi_restart_instance');
  await disconnectInstance().catch((err) => {
    logger.warn('waapi_restart_disconnect_failed', { error: err.message });
  });
  await new Promise((r) => setTimeout(r, 2_000));
  return connectInstance();
}

// ── Messaging ─────────────────────────────────────────────────────

/**
 * Send a plain text message.
 *
 * @param {string} chatId   WAAPI chatId — e.g. "201012345678@c.us"
 * @param {string} message  Text body
 * @returns {Promise<object>} WAAPI response data
 */
async function sendTextMessage(chatId, message) {
  // Log BEFORE the request so failures are always traceable
  logger.info('waapi_send_attempt', {
    chatId,
    messageLength: message.length,
    preview: message.slice(0, 60),
  });

  try {
    const res = await http.post(instancePath('/client/action/send-message'), {
      chatId,
      message,
    });

    logger.info('waapi_message_sent', {
      chatId,
      preview: message.slice(0, 60),
    });

    return extractData(res);
  } catch (err) {
    handleAxiosError(err, {
      action: 'sendTextMessage',
      chatId,
      messageLength: message.length,
    });
  }
}

/**
 * Send a media file (image, video, document, audio).
 *
 * @param {string} chatId    WAAPI chatId
 * @param {string} mediaUrl  Publicly accessible URL
 * @param {string} mediaType "image" | "video" | "document" | "audio"
 * @param {string} caption   Optional caption text
 * @param {string} fileName  Required for documents
 */
async function sendMediaMessage(chatId, mediaUrl, mediaType = 'image', caption = '', fileName = '') {
  logger.info('waapi_media_send_attempt', { chatId, mediaType, mediaUrl });

  const payload = { chatId, mediaUrl, mediaType, caption };
  if (fileName) payload.fileName = fileName;

  try {
    const res = await http.post(instancePath('/client/action/send-media'), payload);
    logger.info('waapi_media_sent', { chatId, mediaType });
    return extractData(res);
  } catch (err) {
    handleAxiosError(err, { action: 'sendMediaMessage', chatId, mediaType });
  }
}

/**
 * Show "typing…" indicator. Non-critical — fails silently.
 * @param {string} chatId
 */
async function sendTyping(chatId) {
  try {
    await http.post(instancePath('/client/action/send-typing'), { chatId, typing: true });
  } catch (err) {
    logger.debug('waapi_typing_failed', { chatId, error: err.message });
  }
}

/**
 * Stop "typing…" indicator. Non-critical — fails silently.
 * @param {string} chatId
 */
async function stopTyping(chatId) {
  try {
    await http.post(instancePath('/client/action/send-typing'), { chatId, typing: false });
  } catch (err) {
    logger.debug('waapi_stop_typing_failed', { chatId, error: err.message });
  }
}

/**
 * Mark a message as read (delivers blue ticks).
 * @param {string} messageId
 * @param {string} chatId
 */
async function markMessageRead(messageId, chatId) {
  try {
    await http.post(instancePath('/client/action/mark-message-read'), {
      messageId,
      chatId,
    });
  } catch (err) {
    logger.warn('waapi_mark_read_failed', { messageId, chatId, error: err.message });
  }
}

/**
 * Get all chats for this instance.
 */
async function getChats() {
  try {
    const res = await http.get(instancePath('/client/chats'));
    return extractData(res);
  } catch (err) {
    handleAxiosError(err, { action: 'getChats' });
  }
}

/**
 * Get messages from a specific chat.
 * @param {string} chatId
 * @param {number} limit
 */
async function getChatMessages(chatId, limit = 20) {
  try {
    const res = await http.get(instancePath(`/client/chats/${chatId}/messages`), {
      params: { limit },
    });
    return extractData(res);
  } catch (err) {
    handleAxiosError(err, { action: 'getChatMessages', chatId });
  }
}

module.exports = {
  WaapiError,
  getInstanceStatus,
  connectInstance,
  disconnectInstance,
  getQRCode,
  restartInstance,
  sendTextMessage,
  sendMediaMessage,
  sendTyping,
  stopTyping,
  markMessageRead,
  getChats,
  getChatMessages,
};
