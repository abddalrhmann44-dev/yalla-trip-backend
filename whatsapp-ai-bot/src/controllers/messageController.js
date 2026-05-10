'use strict';

/**
 * REST API controller for outbound messages.
 * Validation is handled upstream by requestValidator middleware —
 * by the time these functions run, inputs are guaranteed valid.
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
    const chatId = formatChatId(phone.trim());

    logger.info('api_send_text', {
      chatId,
      rawPhone: phone,
      messageLength: message.length,
      preview: message.slice(0, 60),
    });

    const result = await waapiService.sendTextMessage(chatId, message);

    res.json({ success: true, chatId, result });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/messages/send-media
 * Body: { phone, mediaUrl, mediaType?, caption?, fileName? }
 */
async function sendMedia(req, res, next) {
  try {
    const {
      phone,
      mediaUrl,
      mediaType = 'image',
      caption = '',
      fileName = '',
    } = req.body;

    const chatId = formatChatId(phone.trim());

    logger.info('api_send_media', { chatId, rawPhone: phone, mediaType, mediaUrl });

    const result = await waapiService.sendMediaMessage(
      chatId,
      mediaUrl,
      mediaType,
      caption,
      fileName
    );

    res.json({ success: true, chatId, result });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/messages/:phone
 * Returns recent messages from a chat.
 * Query param: ?limit=20
 */
async function getChatMessages(req, res, next) {
  try {
    const chatId = formatChatId(req.params.phone.trim());
    const limit = Math.min(parseInt(req.query.limit || '20', 10), 100);

    logger.info('api_get_messages', { chatId, limit });

    const messages = await waapiService.getChatMessages(chatId, limit);
    res.json({ chatId, count: Array.isArray(messages) ? messages.length : undefined, messages });
  } catch (err) {
    next(err);
  }
}

module.exports = { sendText, sendMedia, getChatMessages };
