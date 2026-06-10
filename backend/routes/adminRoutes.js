const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');

router.get('/users', adminController.getAllUsers);
router.post('/users', adminController.createUser);
router.get('/stats', adminController.getSystemStats);
// Add these below your other routes
router.post('/store', adminController.addStoreItem);
router.put('/store/:item_id', adminController.updateItemPrice);
router.get('/topics', adminController.getTopics);
router.post('/topics', adminController.addTopic);

module.exports = router;
