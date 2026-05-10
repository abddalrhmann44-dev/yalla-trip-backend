'use strict';

const { Router } = require('express');
const ctrl = require('../controllers/instanceController');

const router = Router();

// GET  /api/instance/status  — connection status
router.get('/status', ctrl.getStatus);

// GET  /api/instance/qr      — get QR code for scanning
router.get('/qr', ctrl.getQR);

// POST /api/instance/connect
router.post('/connect', ctrl.connect);

// POST /api/instance/disconnect
router.post('/disconnect', ctrl.disconnect);

// POST /api/instance/restart
router.post('/restart', ctrl.restart);

// GET  /api/instance/chats   — list all chats
router.get('/chats', ctrl.getChats);

module.exports = router;
