const express = require('express');
const router = express.Router();

// Placeholder routes - to be implemented with authController
router.get('/', (req, res) => {
  res.json({ message: 'Auth endpoint ready' });
});

module.exports = router;
