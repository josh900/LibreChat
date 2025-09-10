const express = require('express');
const { modelController, fetchUserModelsController } = require('~/server/controllers/ModelController');
const { requireJwtAuth } = require('~/server/middleware/');

const router = express.Router();
router.get('/', requireJwtAuth, modelController);
router.post('/fetch', requireJwtAuth, fetchUserModelsController);

module.exports = router;
