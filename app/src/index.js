const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    version: process.env.APP_VERSION || '1.0.0'
  });
});

app.get('/orders', (req, res) => {
  res.status(200).json({
    orders: [],
    message: 'Order service running'
  });
});

app.post('/orders', (req, res) => {
  const { item, quantity } = req.body;

  if (!item || !quantity) {
    return res.status(400).json({
      error: 'item and quantity are required'
    });
  }

  res.status(201).json({
    id: Date.now(),
    item,
    quantity,
    status: 'created'
  });
});

/*
  IMPORTANT:
  Only start the server when this file is run directly.
  Do NOT start during Jest tests.
*/
if (require.main === module) {
  app.listen(PORT, () => {
    console.log('Order service listening on port ' + PORT);
  });
}

module.exports = app;
