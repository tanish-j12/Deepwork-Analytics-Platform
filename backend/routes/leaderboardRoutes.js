const express = require('express');
const router = express.Router();
const leaderboardController = require('../controllers/leaderboardController');

// GET /api/leaderboard/global
router.get('/global', leaderboardController.getGlobalLeaderboard);

// GET /api/leaderboard/group/3 (where 3 is the tg_id)
router.get('/group/:tg_id', leaderboardController.getGroupLeaderboard);

module.exports = router;