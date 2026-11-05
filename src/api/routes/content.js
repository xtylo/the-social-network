// Defines the API routes for content and recommendations.
import { HeadObjectCommand } from '@aws-sdk/client-s3';
import { Router } from 'express';
import { z } from 'zod';

import { pool } from '../db.js';
import { BUCKET, s3 } from '../s3.js';

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

const CATEGORIES = 16;
const FOREIGN_KEY_VIOLATION = '23503';

const newContentSchema = z.object({
  creatorId: z.number().int().positive().max(2_147_483_647),
  title: z.string().min(1).max(200),
  category: z.number().int().min(0).max(CATEGORIES - 1),
  key: z.string().startsWith('creators/'),
});

// Category vector, same shape as the seed: 1.0 in the category dimension and 0.15 elsewhere
// (0.15 is the average noise of the seed). Returned as a pgvector literal: "[0.15,...,1,...]".
function categoryVector(category) {
  const values = Array.from({ length: CATEGORIES }, (_, i) => (i === category ? 1 : 0.15));
  return JSON.stringify(values);
}

// POST /content -> registers a file that was already uploaded with a presigned URL.
router.post('/content', async (req, res) => {
  const parsed = newContentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'invalid body', details: z.flattenError(parsed.error).fieldErrors });
  }
  const { creatorId, title, category, key } = parsed.data;

  // The file must really be in S3 before we publish it.
  try {
    await s3.send(new HeadObjectCommand({ Bucket: BUCKET, Key: key }));
  } catch (err) {
    if (err.$metadata?.httpStatusCode === 404) {
      return res.status(400).json({ error: 'file not found in S3: upload it first' });
    }
    throw err;
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO content (creator_id, title, category, s3_key, embedding)
       VALUES ($1, $2, $3, $4, $5::vector)
       RETURNING id, creator_id AS "creatorId", title, category, s3_key AS "s3Key", created_at AS "createdAt"`,
      [creatorId, title, category, key, categoryVector(category)],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === FOREIGN_KEY_VIOLATION) {
      return res.status(404).json({ error: 'creator not found' });
    }
    throw err;
  }
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