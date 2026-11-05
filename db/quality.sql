-- Recommendation quality on the synthetic data.
-- Each user prefers category (id % 16), so we can check how many of the top 10 fall in it.
-- Run: psql "$DATABASE_URL" -f db/quality.sql
\timing on

-- Hit rate of the recommender for the first 100 users.
WITH sample AS (SELECT id FROM users ORDER BY id LIMIT 100),
profiles AS (
  SELECT s.id AS user_id, AVG(c.embedding) AS v
  FROM sample s
  JOIN interactions i ON i.user_id = s.id AND i.type IN ('like', 'share')
  JOIN content c ON c.id = i.content_id
  GROUP BY s.id
),
recs AS (
  SELECT p.user_id, r.category
  FROM profiles p
  CROSS JOIN LATERAL (
    SELECT c.category FROM content c
    WHERE NOT EXISTS (SELECT 1 FROM interactions i WHERE i.user_id = p.user_id AND i.content_id = c.id)
    ORDER BY c.embedding <=> p.v
    LIMIT 10
  ) r
)
SELECT count(*) AS recommendations,
       round(100.0 * avg((category = user_id % 16)::int), 2) AS hit_rate_pct
FROM recs;

-- Baseline: 10 random content items per user. Expected about 1/16 = 6.25%.
-- "c.id > s.id * 0" is always true; it only forces Postgres to pick new random rows for each user.
WITH sample AS (SELECT id FROM users ORDER BY id LIMIT 100),
recs AS (
  SELECT s.id AS user_id, r.category
  FROM sample s
  CROSS JOIN LATERAL (SELECT c.category FROM content c WHERE c.id > s.id * 0 ORDER BY random() LIMIT 10) r
)
SELECT count(*) AS recommendations,
       round(100.0 * avg((category = user_id % 16)::int), 2) AS random_hit_rate_pct
FROM recs;