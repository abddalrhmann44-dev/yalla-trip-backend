'use strict';

/**
 * REST API controller for manually sending messages.
 * Useful for outbound notifications, testing, or admin dashboards.
 */

const waapiService = require('../services/waapiService');
const { formatChatId } = require('../utils/phoneUtils');
const logger = require('../config/logger');

/**
 * POST /api/messages/send
 * Body: { phone, message }
 */
async function sendText(req, res, next) {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ error: '"phone" and "message" are required.' });
    }

    const chatId = formatChatId(phone);
    const result = await waapiService.sendTextMessage(chatId, message);

    res.json({ success: true, chatId, result });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/messages/send-media
 * Body: { phone, mediaUrl, mediaType, caption, fileName }
 */
async function sendMedia(req, res, next) {
  try {
    const { phone, mediaUrl, mediaType = 'image', caption = '', fileName = '' } = req.body;

    if (!phone || !mediaUrl) {
      return res.status(400).json({ error: '"phone" and "mediaUrl" are required.' });
    }

    const chatId = formatChatId(phone);
    const result = await waapiService.sendMediaMessage(chatId, mediaUrl, mediaType, caption, fileName);

    res.json({ success: true, chatId, result });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/messages/:phone
 * Returns recent messages from a chat.
 */
async function getChatMessages(req, res, next) {
  try {
    const chatId = formatChatId(req.params.phone);
    const limit = parseInt(req.query.limit || '20', 10);

    const messages = await waapiService.getChatMessages(chatId, limit);
    res.json({ chatId, messages });
  } catch (err) {
    next(err);
  }
}

module.exports = { sendText, sendMedia, getChatMessages };
