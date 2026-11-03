-- Esquema base. Se ejecuta automaticamente la primera vez que arranca el contenedor de Postgres
-- (todo lo que esta en /docker-entrypoint-initdb.d corre en orden alfabetico).

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
  PRIMARY KEY (user_id, content_id, type)  -- idempotencia: un like repetido no se duplica
);

CREATE INDEX interactions_content_idx ON interactions (content_id);

-- El indice HNSW se crea a proposito el DIA 7, para medir la consulta antes y despues.
-- CREATE INDEX content_embedding_hnsw ON content USING hnsw (embedding vector_cosine_ops);
--
-- OJO (comprobado con los datos del seed): con el indice HNSW, LIMIT 50 devuelve solo ~40 filas,
-- porque hnsw.ef_search vale 40 por defecto y el filtro "ya visto" descarta candidatos.
-- Solucion para cualquier version de pgvector:   SET hnsw.ef_search = 100;
-- Con pgvector >= 0.8 (la imagen de Docker):      SET hnsw.iterative_scan = relaxed_order;
