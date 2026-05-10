'use strict';

const { Router } = require('express');
const { sendText, sendMedia, getChatMessages } = require('../controllers/messageController');
const { validateSendText, validateSendMedia, validateGetMessages } = require('../middlewares/requestValidator');

const router = Router();

// POST /api/messages/send — send plain text
router.post('/send', validateSendText, sendText);

// POST /api/messages/send-media — send image / video / document / audio
router.post('/send-media', validateSendMedia, sendMedia);

// GET  /api/messages/:phone — get chat history
router.get('/:phone', validateGetMessages, getChatMessages);

module.exports = router;
