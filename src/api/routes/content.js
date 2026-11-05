// Defines the API routes for content and recommendations.
import { Router } from 'express';
import { z } from 'zod';

import { pool } from '../db.js';

const router = Router();

// Validates that a URL parameter is a positive integer that fits in a Postgres int ("42" -> 42).
const idSchema = z.coerce.number().int().positive().max(2_147_483_647);

const RECO_URL = process.env.RECO_URL ?? 'http://localhost:8080';

// GET /content/:id
router.get('/content/:id', async (req, res) => {
  const parsed = idSchema.safeParse(req.params.id);
  if (!parsed.success) {
    return res.status(400).json({ error: 'id must be a positive integer' });
  }

  const { rows } = await pool.query(
    `SELECT id, creator_id AS "creatorId", title, category, s3_key AS "s3Key", created_at AS "createdAt"
     FROM content
     WHERE id = $1`,
    [parsed.data],
  );

  if (rows.length === 0) {
    return res.status(404).json({ error: 'content not found' });
  }
  res.json(rows[0]);
});

// GET /recommendations/:userId -> forwards to the Rust recommendation service.
router.get('/recommendations/:userId', async (req, res) => {
  const parsed = idSchema.safeParse(req.params.userId);
  if (!parsed.success) {
    return res.status(400).json({ error: 'userId must be a positive integer' });
  }

  try {
    const response = await fetch(`${RECO_URL}/recommendations/${parsed.data}`, {
      signal: AbortSignal.timeout(2000), // never wait more than 2 s for Rust
    });
    if (!response.ok) {
      req.log.error({ status: response.status }, 'reco service returned an error');
      return res.status(502).json({ error: 'recommendation service error' });
    }
    res.json(await response.json());
  } catch (err) {
    // Rust is down or too slow: 502 Bad Gateway (the problem is upstream, not in this API).
    req.log.error({ err }, 'reco service unreachable');
    res.status(502).json({ error: 'recommendation service unavailable' });
  }
});

export default router;