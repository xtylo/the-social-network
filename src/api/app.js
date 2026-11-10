// Builds the Express app. Kept apart from server.js so tests can import it without opening a port.
import express from 'express';
import { pinoHttp } from 'pino-http';

import { pool } from './db.js';
import { logger } from './logger.js';
import contentRoutes from './routes/content.js';
import feedRoutes from './routes/feed.js';
import interactionRoutes from './routes/interactions.js';
import uploadRoutes from './routes/uploads.js';

export const app = express();

app.use(express.json()); // parse JSON request bodies
app.use(pinoHttp({ logger })); // one log line per request, available as req.log

// GET /health -> 200 if the database answers, 503 if not.
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok' });
  } catch (err) {
    req.log.error({ err }, 'health check failed');
    res.status(503).json({ status: 'database unavailable' });
  }
});

app.use(contentRoutes);
app.use(feedRoutes);
app.use(interactionRoutes);
app.use(uploadRoutes);

// Unknown routes.
app.use((req, res) => res.status(404).json({ error: 'not found' }));

// Error handler: Express 5 sends errors thrown in async handlers here automatically.
// It must have 4 parameters so Express recognizes it as an error handler.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  req.log.error({ err }, 'unhandled error');
  res.status(500).json({ error: 'internal server error' });
});