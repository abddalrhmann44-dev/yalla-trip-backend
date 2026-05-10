'use strict';

const { Router } = require('express');
const { handleWebhook } = require('../controllers/webhookController');
const { validateWebhook } = require('../middlewares/authMiddleware');
const { webhookLimiter } = require('../middlewares/rateLimiter');

const router = Router();

/**
 * POST /webhook
 * WAAPI posts all WhatsApp events here.
 * Configure this URL in your waapi.app dashboard → Webhook Settings.
 */
router.post('/', webhookLimiter, validateWebhook, handleWebhook);

module.exports = router;
