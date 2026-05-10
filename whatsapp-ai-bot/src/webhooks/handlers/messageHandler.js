'use strict';

/**
 * Handles incoming WhatsApp messages received via the WAAPI webhook.
 * Flow: receive → queue → Claude → typing delay → send reply
 */

const { config } = require('../../config');
const logger = require('../../config/logger');
const waapiService = require('../../services/waapiService');
const claudeService = require('../../services/claudeService');
const messageQueue = require('../../services/messageQueue');
const { randomDelay } = require('../../utils/delay');
const { formatChatId } = require('../../utils/phoneUtils');

// Commands that reset the conversation
const RESET_COMMANDS = ['/reset', '/clear', '/start', 'reset', 'مسح'];

/**
 * Main entry point — called by webhookController for each "message" event.
 * @param {object} data  - WAAPI message payload
 */
async function handle(data) {
  const {
    id: messageId,
    from,
    body,
    type,
    isGroup,
    isStatus,
    author,
  } = data;

  // ── Filtering ────────────────────────────────────────────────
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

  const chatId = formatChatId(from);
  const text = body.trim();

  logger.info('msg_received', { chatId, preview: text.slice(0, 60) });

  // ── Queue per user ───────────────────────────────────────────
  messageQueue.enqueue(chatId, () => processMessage(chatId, messageId, text));
}

async function processMessage(chatId, messageId, text) {
  try {
    // Mark as read so the sender sees blue ticks
    await waapiService.markMessageRead(messageId, chatId);

    // Reset command
    if (RESET_COMMANDS.includes(text.toLowerCase())) {
      claudeService.resetConversation(chatId);
      await waapiService.sendTextMessage(
        chatId,
        '✅ تم مسح المحادثة. / Conversation cleared. How can I help you?'
      );
      return;
    }

    // Show typing indicator
    await waapiService.sendTyping(chatId);

    // Get Claude's reply
    const reply = await claudeService.processMessage(chatId, text);

    // Simulate realistic typing delay proportional to reply length
    const delay = randomDelay(
      config.bot.typingDelayMin,
      Math.min(config.bot.typingDelayMax, reply.length * 20)
    );
    await new Promise((r) => setTimeout(r, delay));

    // Stop typing indicator and send reply
    await waapiService.stopTyping(chatId);
    await waapiService.sendTextMessage(chatId, reply);

    logger.info('msg_replied', { chatId, replyPreview: reply.slice(0, 60) });
  } catch (err) {
    logger.error('msg_process_error', { chatId, error: err.message });
    // Notify the user something went wrong
    try {
      await waapiService.stopTyping(chatId);
      await waapiService.sendTextMessage(
        chatId,
        '⚠️ عذراً، حدث خطأ. حاول مجدداً. / Sorry, something went wrong. Please try again.'
      );
    } catch {
      // Swallow send error to avoid crashing the queue
    }
  }
}

module.exports = { handle };
