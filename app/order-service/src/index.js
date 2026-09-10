const express = require('express');
const crypto = require('crypto');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const client = require('@prometheus-io/client');

const app = express();
const PORT = process.env.PORT || 3000;
const orderTableName = process.env.ORDER_TABLE_NAME;
const dynamoClient = orderTableName
  ? DynamoDBDocumentClient.from(new DynamoDBClient({ region: process.env.AWS_REGION }))
  : null;
const localOrders = [];
const metricsRegistry = new client.Registry();
client.collectDefaultMetrics({ register: metricsRegistry });
const requestCounter = new client.Counter({
  name: 'order_service_http_requests_total',
  help: 'Total HTTP requests handled by the Order Service.',
  labelNames: ['method', 'route', 'status_code'],
  registers: [metricsRegistry]
});
const requestDuration = new client.Histogram({
  name: 'order_service_http_request_duration_seconds',
  help: 'HTTP request duration in seconds for the Order Service.',
  labelNames: ['method', 'route'],
  registers: [metricsRegistry]
});

app.use(express.json());
app.use((req, res, next) => {
  const startTime = process.hrtime.bigint();
  res.on('finish', () => {
    const route = req.route?.path || req.path;
    requestCounter.inc({ method: req.method, route, status_code: res.statusCode });
    requestDuration.observe({ method: req.method, route }, Number(process.hrtime.bigint() - startTime) / 1e9);
  });
  next();
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', metricsRegistry.contentType);
  res.end(await metricsRegistry.metrics());
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    version: process.env.APP_VERSION || '1.0.0'
  });
});

app.get('/orders', async (req, res) => {
  if (!dynamoClient) {
    return res.status(200).json({ orders: localOrders, message: 'Order service running' });
  }

  try {
    const result = await dynamoClient.send(new ScanCommand({ TableName: orderTableName }));
    res.status(200).json({ orders: result.Items || [], message: 'Order service running' });
  } catch (error) {
    res.status(500).json({ error: 'unable to read orders' });
  }
});

app.post('/orders', async (req, res) => {
  const { item, quantity, cartItems } = req.body;

  if ((!item || !quantity) && (!Array.isArray(cartItems) || cartItems.length === 0)) {
    return res.status(400).json({
      error: 'item and quantity or cartItems are required'
    });
  }

  const order = {
    order_id: crypto.randomUUID(),
    cart_items: cartItems || [{ item, quantity }],
    status: 'created'
  };

  if (!dynamoClient) {
    localOrders.push(order);
    return res.status(201).json(order);
  }

  try {
    await dynamoClient.send(new PutCommand({ TableName: orderTableName, Item: order }));
    res.status(201).json(order);
  } catch (error) {
    res.status(500).json({ error: 'unable to create order' });
  }
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
// trigger workflow
