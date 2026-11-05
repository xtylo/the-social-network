-- Base schema. Runs automatically the first time the Postgres container starts
-- (everything in /docker-entrypoint-initdb.d runs in alphabetical order).

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE creators (
  id   serial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE users (
  id   serial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE content (
  id         serial PRIMARY KEY,
  creator_id int         NOT NULL REFERENCES creators(id),
  title      text        NOT NULL,
  category   smallint    NOT NULL CHECK (category BETWEEN 0 AND 15),
  s3_key     text,
  embedding  vector(16)  NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE interactions (
  user_id    int         NOT NULL REFERENCES users(id),
  content_id int         NOT NULL REFERENCES content(id),
  type       text        NOT NULL CHECK (type IN ('view', 'like', 'share')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, content_id, type)  -- idempotency: a repeated like is not duplicated
);

CREATE INDEX interactions_content_idx ON interactions (content_id);

-- The HNSW index is created on purpose on DAY 7, to measure the query before and after.
CREATE INDEX content_embedding_hnsw ON content USING hnsw (embedding vector_cosine_ops);
--
-- NOTE (verified with the seed data): with the HNSW index, LIMIT 50 returns only ~40 rows,
-- because hnsw.ef_search defaults to 40 and the "already seen" filter drops candidates.
-- Fix for any pgvector version:               SET hnsw.ef_search = 100;
-- With pgvector >= 0.8 (the Docker image):    SET hnsw.iterative_scan = relaxed_order;
