'use strict';

/**
 * WAAPI Service — all communication with waapi.app REST API.
 * Docs: https://waapi.readme.io/reference/waapi-api-documentation
 */

const axios = require('axios');
const axiosRetry = require('axios-retry').default;
const { config } = require('../config');
const logger = require('../config/logger');

// ---------- HTTP client setup ----------

const http = axios.create({
  baseURL: config.waapi.baseUrl,
  timeout: 30_000,
  headers: {
    Authorization: `Bearer ${config.waapi.apiKey}`,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
});

// Retry on network errors and 5xx with exponential back-off
axiosRetry(http, {
  retries: 3,
  retryDelay: axiosRetry.exponentialDelay,
  retryCondition: (err) =>
    axiosRetry.isNetworkOrIdempotentRequestError(err) ||
    (err.response && err.response.status >= 500),
  onRetry: (retryCount, err) => {
    logger.warn('waapi_retry', { attempt: retryCount, error: err.message });
  },
});

// ---------- Helper ----------

function instancePath(path = '') {
  return `/instances/${config.waapi.instanceId}${path}`;
}

function extractData(response) {
  return response.data;
}

// ---------- Instance management ----------

async function getInstanceStatus() {
  const res = await http.get(instancePath());
  return extractData(res);
}

async function connectInstance() {
  const res = await http.post(instancePath('/client/action/start-session'));
  return extractData(res);
}

async function disconnectInstance() {
  const res = await http.post(instancePath('/client/action/logout'));
  return extractData(res);
}

async function getQRCode() {
  const res = await http.get(instancePath('/client/qr'));
  return extractData(res);
}

async function restartInstance() {
  logger.info('waapi_restart_instance');
  await disconnectInstance().catch(() => {}); // ignore disconnect errors
  await new Promise((r) => setTimeout(r, 2_000));
  return connectInstance();
}

// ---------- Messaging ----------

/**
 * Send a plain text message.
 * @param {string} chatId  - E.g. "201012345678@c.us"
 * @param {string} message - Text body
 */
async function sendTextMessage(chatId, message) {
  const res = await http.post(instancePath('/client/action/send-message'), {
    chatId,
    message,
  });
  logger.info('waapi_message_sent', { chatId, preview: message.slice(0, 60) });
  return extractData(res);
}

/**
 * Send a media file (image, video, document, audio).
 * @param {string} chatId    - WhatsApp chatId
 * @param {string} mediaUrl  - Publicly accessible URL of the media
 * @param {string} mediaType - "image" | "video" | "document" | "audio"
 * @param {string} caption   - Optional caption text
 * @param {string} fileName  - Required for documents
 */
async function sendMediaMessage(chatId, mediaUrl, mediaType = 'image', caption = '', fileName = '') {
  const payload = { chatId, mediaUrl, mediaType, caption };
  if (fileName) payload.fileName = fileName;

  const res = await http.post(instancePath('/client/action/send-media'), payload);
  logger.info('waapi_media_sent', { chatId, mediaType });
  return extractData(res);
}

/**
 * Send a typing indicator (shows "typing…" in WhatsApp).
 * Not all WAAPI plans support this — fails silently if unavailable.
 * @param {string} chatId
 */
async function sendTyping(chatId) {
  try {
    await http.post(instancePath('/client/action/send-typing'), { chatId, typing: true });
  } catch {
    // Non-critical; ignore if endpoint unsupported
  }
}

async function stopTyping(chatId) {
  try {
    await http.post(instancePath('/client/action/send-typing'), { chatId, typing: false });
  } catch {}
}

/**
 * Mark a message as read.
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
    logger.warn('waapi_mark_read_failed', { messageId, error: err.message });
  }
}

/**
 * Get all chats for this instance.
 */
async function getChats() {
  const res = await http.get(instancePath('/client/chats'));
  return extractData(res);
}

/**
 * Get messages from a specific chat.
 * @param {string} chatId
 * @param {number} limit
 */
async function getChatMessages(chatId, limit = 20) {
  const res = await http.get(instancePath(`/client/chats/${chatId}/messages`), {
    params: { limit },
  });
  return extractData(res);
}

module.exports = {
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
