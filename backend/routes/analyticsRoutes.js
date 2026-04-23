const express = require('express');
const router = express.Router();
const analyticsController = require('../controllers/analyticsController');

// 1. Route for the Pie Chart
router.get('/kryptonite/:u_id', analyticsController.getKryptoniteStats);

// 2. Route for the Quick Stats and Trend Graph
router.get('/dashboard/:u_id', analyticsController.getDashboardStats);

module.exports = router;