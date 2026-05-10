'use strict';

/**
 * Handles incoming WhatsApp messages received via the WAAPI webhook.
 * Flow: receive → filter → queue → mark-read → Claude → typing delay → send reply
 */

const { config } = require('../../config');
const logger = require('../../config/logger');
const waapiService = require('../../services/waapiService');
const claudeService = require('../../services/claudeService');
const messageQueue = require('../../services/messageQueue');
const { randomDelay } = require('../../utils/delay');
const { formatChatId } = require('../../utils/phoneUtils');

// All strings that trigger a conversation reset (case-insensitive)
const RESET_COMMANDS = new Set([
  '/reset', '/clear', '/start',
  '!reset', '!clear',
  'reset', 'clear',
  'مسح', 'ابدأ',
]);

/**
 * Main entry point — called by webhookController for each "message" event.
 * @param {object} data  WAAPI message payload
 */
async function handle(data) {
  const {
    id: messageId,
    from,
    body,
    type,
    isGroup,
    isStatus,
    fromMe,
  } = data;

  // ── Sanity checks ────────────────────────────────────────────
  if (!from) {
    logger.warn('msg_missing_from', { data });
    return;
  }

  // Never reply to our own messages
  if (fromMe) {
    logger.debug('msg_ignored_self', { from });
    return;
  }

  if (config.bot.ignoreStatus && isStatus) {
    logger.debug('msg_ignored_status', { from });
    return;
  }

  if (config.bot.ignoreGroups && isGroup) {
    logger.debug('msg_ignored_group', { from });
    return;
  }

  // Only process text messages for AI replies
  if (type !== 'chat') {
    logger.debug('msg_ignored_non_text', { from, type });
    return;
  }

  if (!body || !body.trim()) return;

  // `from` arrives from WAAPI already in chatId format ("number@c.us").
  // formatChatId passes it through unchanged when it contains "@".
  const chatId = formatChatId(from);
  const text = body.trim();

  logger.info('msg_received', {
    chatId,
    messageId,
    preview: text.slice(0, 80),
  });

  // Enqueue per-user so rapid messages are processed in order
  messageQueue.enqueue(chatId, () => processMessage(chatId, messageId, text));
}

async function processMessage(chatId, messageId, text) {
  try {
    // Mark as read — sender sees blue ticks
    await waapiService.markMessageRead(messageId, chatId);

    // Reset command — clear history and confirm
    if (RESET_COMMANDS.has(text.toLowerCase())) {
      claudeService.resetConversation(chatId);
      logger.info('msg_conversation_reset', { chatId });
      await waapiService.sendTextMessage(
        chatId,
        '✅ Conversation cleared. / تم مسح المحادثة. كيف يمكنني مساعدتك؟'
      );
      return;
    }

    // Show typing indicator
    await waapiService.sendTyping(chatId);

    // Get Claude's reply (also persists history internally)
    const reply = await claudeService.processMessage(chatId, text);

    // Simulate realistic typing delay proportional to reply length
    const delay = randomDelay(
      config.bot.typingDelayMin,
      Math.min(config.bot.typingDelayMax, reply.length * 20)
    );
    await new Promise((r) => setTimeout(r, delay));

    await waapiService.stopTyping(chatId);
    await waapiService.sendTextMessage(chatId, reply);

    logger.info('msg_replied', {
      chatId,
      replyLength: reply.length,
      replyPreview: reply.slice(0, 80),
    });
  } catch (err) {
    logger.error('msg_process_error', {
      chatId,
      messageId,
      error: err.message,
      stack: err.stack,
    });

    // Best-effort error notification to the user
    try {
      await waapiService.stopTyping(chatId);
      await waapiService.sendTextMessage(
        chatId,
        '⚠️ Sorry, something went wrong. Please try again. / عذراً، حدث خطأ. حاول مجدداً.'
      );
    } catch {
      // Swallow — avoid crashing the queue processor
    }
  }
}

module.exports = { handle };
