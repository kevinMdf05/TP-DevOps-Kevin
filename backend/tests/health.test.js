const request = require('supertest');

jest.mock('../src/db', () => ({
  pool: { query: jest.fn().mockResolvedValue({ rows: [] }), end: jest.fn() },
  initDb: jest.fn().mockResolvedValue(),
  ping: jest.fn().mockResolvedValue(true),
}));

const { buildApp } = require('../src/app');

describe('API', () => {
  const app = buildApp();

  test('GET /health returns 200 and status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.db).toBe('up');
  });

  test('GET / returns service info', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('tp-backend');
  });

  test('POST /api/messages rejects empty content', async () => {
    const res = await request(app).post('/api/messages').send({ content: '' });
    expect(res.status).toBe(400);
  });
});
