const request = require('supertest');
const app = require('../../src/index');

describe('Catalog Service - Unit Tests', () => {
  test('GET /health returns 200 and healthy status', async () => {
    const response = await request(app).get('/health');

    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('healthy');
  });

  test('GET /products returns the product catalog', async () => {
    const response = await request(app).get('/products');

    expect(response.statusCode).toBe(200);
    expect(response.body.products.length).toBeGreaterThan(0);
  });

  test('GET /products supports search queries', async () => {
    const response = await request(app).get('/products?search=headphones');

    expect(response.statusCode).toBe(200);
    expect(response.body.products).toHaveLength(1);
    expect(response.body.products[0].productId).toBe('p-headphones-001');
  });

  test('GET /products/:productId/inventory returns stock information', async () => {
    const response = await request(app).get('/products/p-laptop-001/inventory');

    expect(response.statusCode).toBe(200);
    expect(response.body.available).toBe(true);
    expect(response.body.quantity).toBeGreaterThan(0);
  });

  test('GET /products/:productId returns 404 for an unknown product', async () => {
    const response = await request(app).get('/products/does-not-exist');

    expect(response.statusCode).toBe(404);
  });
});