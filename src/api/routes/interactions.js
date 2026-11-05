// Defines the API routes for user interactions (view, like, share).
import { Router } from 'express';
import { z } from 'zod';

import { pool } from '../db.js';

const router = Router();

// Request body contract (like a DTO with DataAnnotations in .NET).
const id = z.number().int().positive().max(2_147_483_647); // fits in a Postgres int
const interactionSchema = z.object({
  userId: id,
  contentId: id,
  type: z.enum(['view', 'like', 'share']),
});

// PostgreSQL error code for a foreign key violation (user or content does not exist).
const FOREIGN_KEY_VIOLATION = '23503';

// POST /interactions
router.post('/interactions', async (req, res) => {
  const parsed = interactionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'invalid body', details: z.flattenError(parsed.error).fieldErrors });
  }
  const { userId, contentId, type } = parsed.data;

  try {
    // ON CONFLICT DO NOTHING: repeating the same like is harmless (idempotent).
    const result = await pool.query(
      `INSERT INTO interactions (user_id, content_id, type)
       VALUES ($1, $2, $3)
       ON CONFLICT DO NOTHING`,
      [userId, contentId, type],
    );
    // 201 = created now; 200 = it already existed.
    res.status(result.rowCount === 1 ? 201 : 200).json({ userId, contentId, type, created: result.rowCount === 1 });
  } catch (err) {
    if (err.code === FOREIGN_KEY_VIOLATION) {
      return res.status(404).json({ error: 'user or content not found' });
    }
    throw err; // anything else goes to the error handler in app.js (500)
  }
});

export default router;