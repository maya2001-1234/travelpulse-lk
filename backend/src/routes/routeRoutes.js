const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({ message: 'Transit routes endpoint ready' });
});

module.exports = router;
