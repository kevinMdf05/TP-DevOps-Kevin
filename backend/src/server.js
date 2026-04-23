const { buildApp } = require('./app');
const { initDb, pool } = require('./db');

const PORT = parseInt(process.env.PORT || '3000', 10);

async function start() {
  const maxRetries = 20;
  for (let i = 1; i <= maxRetries; i++) {
    try {
      await initDb();
      break;
    } catch (err) {
      console.warn(`[db] init attempt ${i}/${maxRetries} failed: ${err.message}`);
      if (i === maxRetries) throw err;
      await new Promise((r) => setTimeout(r, 2000));
    }
  }

  const app = buildApp();
  const server = app.listen(PORT, () => {
    console.log(`[server] listening on :${PORT}`);
  });

  const shutdown = async (signal) => {
    console.log(`[server] ${signal} received, shutting down`);
    server.close(() => console.log('[server] http closed'));
    await pool.end();
    process.exit(0);
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

start().catch((err) => {
  console.error('[server] fatal', err);
  process.exit(1);
});
