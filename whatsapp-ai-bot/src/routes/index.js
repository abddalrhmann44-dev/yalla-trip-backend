'use strict';

const { Router } = require('express');
const instanceRoutes = require('./instanceRoutes');
const messageRoutes = require('./messageRoutes');

const router = Router();

router.use('/instance', instanceRoutes);
router.use('/messages', messageRoutes);

module.exports = router;
