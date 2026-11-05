-- Measures the nearest-neighbor query used by the Rust service (user 42).
-- Run: psql "$DATABASE_URL" -f db/explain.sql
SELECT AVG(c.embedding)::text AS v
FROM interactions i JOIN content c ON c.id = i.content_id
WHERE i.user_id = 42 AND i.type IN ('like', 'share') \gset

BEGIN;
SET LOCAL hnsw.ef_search = 100;
EXPLAIN (ANALYZE, COSTS OFF)
SELECT c.id
FROM content c
WHERE NOT EXISTS (SELECT 1 FROM interactions i WHERE i.user_id = 42 AND i.content_id = c.id)
ORDER BY c.embedding <=> :'v'
LIMIT 50;
COMMIT;