const express = require('express');
const router = express.Router();
const sessionController = require('../controllers/sessionController');

router.post('/start', sessionController.startSession);
router.post('/end', sessionController.endSession);
router.get('/stats/:s_id', sessionController.getSessionStats);
router.get('/active/:u_id', sessionController.getActiveSession);

module.exports = router;