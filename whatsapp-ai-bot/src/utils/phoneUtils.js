'use strict';

/**
 * Phone number normalization for WhatsApp / WAAPI.
 *
 * Target format: E.164 digits only (no +), then "@c.us"
 * e.g. "201012345678@c.us"
 *
 * Handles:
 *   +201012345678        → 201012345678@c.us
 *   201012345678         → 201012345678@c.us
 *   01012345678          → 201012345678@c.us  (Egyptian local, 0 → 20)
 *   +20 101 234 5678     → 201012345678@c.us
 *   +20-101-234-5678     → 201012345678@c.us
 *   (020) 101-234-5678   → 201012345678@c.us  (parenthesised 0 prefix)
 *   +966501234567        → 966501234567@c.us
 *   +1 (555) 123-4567    → 15551234567@c.us
 *   201012345678@c.us    → 201012345678@c.us  (pass-through, already formatted)
 */

// Egyptian operator prefixes: 010 011 012 015 — always 11 local digits
const EG_LOCAL_RE = /^0(10|11|12|15)\d{8}$/;

/**
 * Strip formatting and normalise to pure digits with country code.
 * Throws a descriptive Error if the result is not plausible E.164.
 *
 * @param {string} input
 * @returns {string} Digits only, with country code (e.g. "201012345678")
 */
function normalizePhone(input) {
  if (!input || typeof input !== 'string') {
    throw new Error('Phone number must be a non-empty string');
  }

  // Strip every character that is not a digit or a leading +
  let n = input.trim();
  // Remove common formatting: spaces, dashes, dots, parentheses, slashes
  n = n.replace(/[\s\-.()/]/g, '');
  // Strip leading + (E.164 marker — we work with raw digits)
  if (n.startsWith('+')) n = n.slice(1);
  // Now strip anything remaining that is not a digit
  n = n.replace(/\D/g, '');

  if (!n) {
    throw new Error(`No digits found in phone number: "${input}"`);
  }

  // ── Egyptian local format ─────────────────────────────────────
  // 01012345678 (11 digits, starts 010/011/012/015) → 201012345678
  if (EG_LOCAL_RE.test(n)) {
    n = '2' + n;
  }

  // ── E.164 plausibility check (ITU-T: 7–15 digits) ────────────
  if (n.length < 7 || n.length > 15) {
    throw new Error(
      `Phone "${input}" normalises to "${n}" (${n.length} digits) — ` +
        'valid E.164 numbers have 7–15 digits'
    );
  }

  return n;
}

/**
 * Convert any phone representation to a WAAPI chatId.
 *
 * @param {string} raw  Phone number in any format, or an existing chatId
 * @returns {string}    e.g. "201012345678@c.us"
 * @throws  {Error}     If the number cannot be normalised
 */
function formatChatId(raw) {
  if (!raw) throw new Error('Phone number is required');

  const str = String(raw).trim();

  // Already a formatted WAAPI chatId — pass through unchanged
  if (str.includes('@')) return str;

  const digits = normalizePhone(str);
  return `${digits}@c.us`;
}

/**
 * Extract a phone string from a chatId.
 * "201012345678@c.us" → "+201012345678"
 *
 * @param {string} chatId
 * @returns {string}
 */
function chatIdToPhone(chatId) {
  if (!chatId) return chatId;
  const digits = chatId.replace(/@[cg]\.us$|@newsletter$/, '');
  return `+${digits}`;
}

module.exports = { normalizePhone, formatChatId, chatIdToPhone };
