// Defines the API route that lets a creator upload a file straight to S3.
import { randomUUID } from 'node:crypto';
import path from 'node:path';

import { PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Router } from 'express';
import { z } from 'zod';

import { BUCKET, s3 } from '../s3.js';

const router = Router();

const URL_TTL_SECONDS = 600; // the presigned URL is valid for 10 minutes

const presignSchema = z.object({
  creatorId: z.number().int().positive().max(2_147_483_647),
  filename: z.string().min(1).max(200),
  contentType: z.string().regex(/^(image|video)\/[\w.+-]+$/, 'must be an image/* or video/* type'),
});

// POST /uploads/presign -> { url, key, expiresIn }
// The client then does: PUT <url> with the file as body and the same Content-Type header.
// The file never passes through this API.
router.post('/uploads/presign', async (req, res) => {
  const parsed = presignSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'invalid body', details: z.flattenError(parsed.error).fieldErrors });
  }
  const { creatorId, filename, contentType } = parsed.data;

  // Our own key: never trust the client's file name (it could contain "../" or collide with others).
  const extension = path.extname(filename).toLowerCase();
  const key = `creators/${creatorId}/${randomUUID()}${extension}`;

  const command = new PutObjectCommand({ Bucket: BUCKET, Key: key, ContentType: contentType });
  const url = await getSignedUrl(s3, command, { expiresIn: URL_TTL_SECONDS });

  res.status(201).json({ url, key, expiresIn: URL_TTL_SECONDS });
});

export default router;