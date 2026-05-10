'use strict';

/**
 * REST API controller for WhatsApp instance management.
 */

const waapiService = require('../services/waapiService');
const conversationService = require('../services/conversationService');
const messageQueue = require('../services/messageQueue');
const logger = require('../config/logger');

async function getStatus(req, res, next) {
  try {
    const status = await waapiService.getInstanceStatus();
    res.json(status);
  } catch (err) {
    next(err);
  }
}

async function getQR(req, res, next) {
  try {
    const qr = await waapiService.getQRCode();
    res.json(qr);
  } catch (err) {
    next(err);
  }
}

async function connect(req, res, next) {
  try {
    const result = await waapiService.connectInstance();
    res.json({ success: true, result });
  } catch (err) {
    next(err);
  }
}

async function disconnect(req, res, next) {
  try {
    const result = await waapiService.disconnectInstance();
    res.json({ success: true, result });
  } catch (err) {
    next(err);
  }
}

async function restart(req, res, next) {
  try {
    const result = await waapiService.restartInstance();
    res.json({ success: true, result });
  } catch (err) {
    next(err);
  }
}

async function getChats(req, res, next) {
  try {
    const chats = await waapiService.getChats();
    res.json(chats);
  } catch (err) {
    next(err);
  }
}

/**
 * GET /health — lightweight health check for Railway monitoring
 */
async function health(req, res) {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    activeSessions: conversationService.activeSessions(),
    activeQueues: messageQueue.activeQueues(),
    timestamp: new Date().toISOString(),
  });
}

module.exports = { getStatus, getQR, connect, disconnect, restart, getChats, health };
