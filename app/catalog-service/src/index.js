const express = require('express');
const client = require('@prometheus-io/client');

const app = express();
const port = process.env.PORT || 3000;
const metricsRegistry = new client.Registry();
client.collectDefaultMetrics({ register: metricsRegistry });
const requestCounter = new client.Counter({
  name: 'catalog_service_http_requests_total',
  help: 'Total HTTP requests handled by the Catalog Service.',
  labelNames: ['method', 'route', 'status_code'],
  registers: [metricsRegistry]
});
const requestDuration = new client.Histogram({
  name: 'catalog_service_http_request_duration_seconds',
  help: 'HTTP request duration in seconds for the Catalog Service.',
  labelNames: ['method', 'route'],
  registers: [metricsRegistry]
});

const products = [
  {
    productId: 'p-laptop-001',
    name: 'MegaBook Pro 14',
    description: '14-inch laptop for work and study',
    price: 1299.99,
    stock: 24,
    category: 'electronics'
  },
  {
    productId: 'p-headphones-001',
    name: 'MegaSound Wireless Headphones',
    description: 'Noise-cancelling wireless headphones',
    price: 149.99,
    stock: 80,
    category: 'electronics'
  }
];

app.use(express.json());
app.use((request, response, next) => {
  const startTime = process.hrtime.bigint();
  response.on('finish', () => {
    const route = request.route?.path || request.path;
    requestCounter.inc({ method: request.method, route, status_code: response.statusCode });
    requestDuration.observe({ method: request.method, route }, Number(process.hrtime.bigint() - startTime) / 1e9);
  });
  next();
});

app.get('/metrics', async (request, response) => {
  response.set('Content-Type', metricsRegistry.contentType);
  response.end(await metricsRegistry.metrics());
});

app.get('/health', (request, response) => {
  response.status(200).json({
    status: 'healthy',
    version: process.env.APP_VERSION || '1.0.0'
  });
});

app.get('/products', (request, response) => {
  const category = request.query.category;
  const search = request.query.search?.toLowerCase();
  const matchingProducts = products.filter((product) => {
    const matchesCategory = !category || product.category === category;
    const matchesSearch = !search || [product.name, product.description, product.category]
      .some((field) => field.toLowerCase().includes(search));
    return matchesCategory && matchesSearch;
  });

  response.status(200).json({ products: matchingProducts });
});

app.get('/products/:productId', (request, response) => {
  const product = products.find((candidate) => candidate.productId === request.params.productId);

  if (!product) {
    return response.status(404).json({ error: 'product not found' });
  }

  response.status(200).json(product);
});

app.get('/products/:productId/inventory', (request, response) => {
  const product = products.find((candidate) => candidate.productId === request.params.productId);

  if (!product) {
    return response.status(404).json({ error: 'product not found' });
  }

  response.status(200).json({
    productId: product.productId,
    available: product.stock > 0,
    quantity: product.stock
  });
});

if (require.main === module) {
  app.listen(port, () => {
    console.log('Catalog service listening on port ' + port);
  });
}

module.exports = app;