const express = require('express');
const router = express.Router();
const storeController = require('../controllers/storeController');

router.get('/items', storeController.getStoreItems);
router.post('/buy', storeController.purchaseItem);
router.get('/inventory/:u_id', storeController.getUserInventory);

module.exports = router;