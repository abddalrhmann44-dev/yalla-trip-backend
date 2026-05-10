'use strict';

/**
 * Simple per-chat FIFO queue that ensures messages for the same user
 * are processed serially (no overlapping Claude calls / send races).
 *
 * Architecture: one Promise chain per chatId. New tasks are chained
 * onto the tail of the previous one via Promise.then — no libraries needed.
 */

const logger = require('../config/logger');

// Map<chatId, Promise> — the tail of each chat's processing chain
const queues = new Map();

/**
 * Enqueue a task for a specific chat.
 * Tasks for the same chatId run one-at-a-time in arrival order.
 * Tasks for different chatIds run concurrently.
 *
 * @param {string}   chatId
 * @param {Function} task   - async () => any
 * @returns {Promise}       - resolves/rejects with the task result
 */
function enqueue(chatId, task) {
  // Build on top of the existing tail (or a resolved promise if none)
  const previous = queues.get(chatId) || Promise.resolve();

  const next = previous.then(
    () => task(),
    () => task() // run even if the previous task failed
  );

  // Replace the tail; clean up when fully settled so the Map doesn't grow forever
  const cleanup = next.finally(() => {
    if (queues.get(chatId) === cleanup) {
      queues.delete(chatId);
    }
  });

  queues.set(chatId, cleanup);
  return next;
}

/**
 * Number of chats currently with queued/running work.
 */
function activeQueues() {
  return queues.size;
}

module.exports = { enqueue, activeQueues };
