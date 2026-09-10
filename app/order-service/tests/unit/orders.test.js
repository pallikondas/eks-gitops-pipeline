const request = require('supertest');
const app = require('../../src/index');

describe('Order Service - Unit Tests', () => {
  test('GET /health returns 200 and healthy status', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('healthy');
  });

  test('POST /orders with valid body returns 201', async () => {
    const response = await request(app)
      .post('/orders')
      .send({ item: 'laptop', quantity: 1 });
    expect(response.statusCode).toBe(201);
    expect(response.body.status).toBe('created');
  });

  test('POST /orders with missing fields returns 400', async () => {
    const response = await request(app)
      .post('/orders')
      .send({ item: 'laptop' });
    expect(response.statusCode).toBe(400);
  });
});
