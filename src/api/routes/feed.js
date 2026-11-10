// Defines the feed route with an A/B test: half of the users get the recommended feed (Rust service),
// the other half the chronological feed (newest content). Every item shown is logged as an impression.
import { createHash } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import { pool } from '../db.js';

const router = Router();

const idSchema = z.coerce.number().int().positive().max(2_147_483_647);
const RECO_URL = process.env.RECO_URL ?? 'http://localhost:8080';
const FEED_SIZE = 10;

// Stable assignment: the same user always gets the same variant. A hash avoids patterns tied to the id itself
// (for example, even ids would also share preferences in the synthetic data).
export function variantFor(userId) {
  const firstByte = createHash('sha256').update(String(userId)).digest()[0];
  return firstByte % 2 === 0 ? 'recommended' : 'chronological';
}

// Variant A: ids from the Rust recommendation service.
async function recommendedIds(userId) {
  const response = await fetch(`${RECO_URL}/recommendations/${userId}`, { signal: AbortSignal.timeout(2000) });
  if (!response.ok) {
    throw new Error(`reco service returned ${response.status}`);
  }
  const body = await response.json();
  return body.items.map((item) => item.id);
}

// Variant B: the newest content the user has not interacted with yet.
async function chronologicalIds(userId) {
  const { rows } = await pool.query(
    `SELECT c.id FROM content c
     WHERE NOT EXISTS (SELECT 1 FROM interactions i WHERE i.user_id = $1 AND i.content_id = c.id)
     ORDER BY c.created_at DESC, c.id DESC
     LIMIT $2`,
    [userId, FEED_SIZE],
  );
  return rows.map((row) => row.id);
}

// GET /feed/:userId -> { userId, variant, items: [{ position, id, creatorId, title, category }] }
router.get('/feed/:userId', async (req, res) => {
  const parsed = idSchema.safeParse(req.params.userId);
  if (!parsed.success) {
    return res.status(400).json({ error: 'userId must be a positive integer' });
  }
  const userId = parsed.data;
  const variant = variantFor(userId);

  let ids;
  try {
    ids = variant === 'recommended' ? await recommendedIds(userId) : await chronologicalIds(userId);
  } catch (err) {
    req.log.error({ err }, 'feed source failed');
    return res.status(502).json({ error: 'feed unavailable' });
  }

  // Item details in the order of the feed (WITH ORDINALITY keeps the array order as the position).
  const { rows: items } = await pool.query(
    `SELECT f.position::int AS position, c.id, c.creator_id AS "creatorId", c.title, c.category
     FROM unnest($1::int[]) WITH ORDINALITY AS f(content_id, position)
     JOIN content c ON c.id = f.content_id
     ORDER BY f.position`,
    [ids],
  );

  // Log what was shown: one row per item, in a single insert.
  await pool.query(
    `INSERT INTO feed_impressions (user_id, content_id, position, variant)
     SELECT $1, f.content_id, f.position, $2
     FROM unnest($3::int[]) WITH ORDINALITY AS f(content_id, position)`,
    [userId, variant, ids],
  );

  res.json({ userId, variant, items });
});

export default router;
