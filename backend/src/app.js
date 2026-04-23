const express = require('express');
const cors = require('cors');
const { pool, ping } = require('./db');
const { register, metricsMiddleware } = require('./metrics');

function buildApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());
  app.use(metricsMiddleware);

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  app.get('/health', async (_req, res) => {
    try {
      const dbOk = await ping();
      return res.status(200).json({
        status: 'ok',
        db: dbOk ? 'up' : 'down',
        uptime: process.uptime(),
      });
    } catch (err) {
      return res.status(503).json({ status: 'degraded', db: 'down', error: err.message });
    }
  });

  app.get('/api/messages', async (_req, res) => {
    try {
      const { rows } = await pool.query(
        'SELECT id, content, created_at FROM messages ORDER BY id DESC LIMIT 50'
      );
      return res.json(rows);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/messages', async (req, res) => {
    const content = (req.body && req.body.content ? String(req.body.content) : '').trim();
    if (!content) return res.status(400).json({ error: 'content is required' });
    try {
      const { rows } = await pool.query(
        'INSERT INTO messages (content) VALUES ($1) RETURNING id, content, created_at',
        [content]
      );
      return res.status(201).json(rows[0]);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  app.get('/', (_req, res) => {
    res.json({ name: 'tp-backend', version: '1.0.0' });
  });

  return app;
}

module.exports = { buildApp };
