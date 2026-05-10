'use strict';

/**
 * Ensure a chatId is in WAAPI format: "{number}@c.us"
 * Accepts raw E.164 (+201012345678), digits only, or already-formatted IDs.
 */
function formatChatId(raw) {
  if (!raw) return raw;
  if (raw.includes('@')) return raw; // already formatted
  const digits = raw.replace(/\D/g, '');
  return `${digits}@c.us`;
}

/**
 * Extract the phone number string from a chatId.
 * "201012345678@c.us" → "+201012345678"
 */
function chatIdToPhone(chatId) {
  if (!chatId) return chatId;
  return '+' + chatId.replace('@c.us', '').replace('@g.us', '');
}

module.exports = { formatChatId, chatIdToPhone };
