'use strict';

const { Router } = require('express');
const { sendText, sendMedia, getChatMessages } = require('../controllers/messageController');

const router = Router();

// POST /api/messages/send         — send text
router.post('/send', sendText);

// POST /api/messages/send-media   — send image / video / document
router.post('/send-media', sendMedia);

// GET  /api/messages/:phone       — get chat history
router.get('/:phone', getChatMessages);

module.exports = router;
