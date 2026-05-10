'use strict';

/**
 * Claude AI Service — wraps the Anthropic SDK.
 * Maintains per-user conversation context via conversationService.
 */

const Anthropic = require('@anthropic-ai/sdk');
const { config } = require('../config');
const logger = require('../config/logger');
const conversationService = require('./conversationService');

const client = new Anthropic.Anthropic({ apiKey: config.claude.apiKey });

/**
 * Process an incoming user message through Claude and return the reply.
 *
 * @param {string} chatId      - WhatsApp chatId (used as conversation key)
 * @param {string} userMessage - The raw text from the user
 * @returns {Promise<string>}  - Claude's text response
 */
async function processMessage(chatId, userMessage) {
  // Load conversation history for this user
  const history = conversationService.getHistory(chatId);

  // Append the new user turn
  conversationService.addMessage(chatId, 'user', userMessage);

  // Build the full messages array for this request
  const messages = [...history, { role: 'user', content: userMessage }];

  logger.debug('claude_request', {
    chatId,
    historyLength: history.length,
    userMessage: userMessage.slice(0, 80),
  });

  const response = await client.messages.create({
    model: config.claude.model,
    max_tokens: config.claude.maxTokens,
    system: config.claude.systemPrompt,
    messages,
  });

  const reply = response.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('');

  // Persist the assistant turn
  conversationService.addMessage(chatId, 'assistant', reply);

  logger.debug('claude_response', {
    chatId,
    inputTokens: response.usage.input_tokens,
    outputTokens: response.usage.output_tokens,
    reply: reply.slice(0, 80),
  });

  return reply;
}

/**
 * Reset the conversation history for a user.
 */
function resetConversation(chatId) {
  conversationService.clearHistory(chatId);
}

module.exports = { processMessage, resetConversation };
