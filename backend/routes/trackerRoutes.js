const express = require('express');
const router = express.Router();
const trackerController = require('../controllers/trackerController');

// This handles the POST request coming from Python
router.post('/log', trackerController.logActivity);

module.exports = router;