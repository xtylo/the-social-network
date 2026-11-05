# Results

Measured locally in the dev container (Docker Desktop on Windows, WSL 2) on November 4, 2026.
Dataset from `db/02_seed.sql`: 100,000 content items with 16-dimension vectors, 10,000 users, 200,000 likes.
PostgreSQL 17 with pgvector 0.8.7.

## Nearest-neighbor query

Query used by the Rust service: top 50 unseen content items closest to user 42's profile (cosine distance).
Reproduce with `psql "$DATABASE_URL" -f db/explain.sql`.

| Setup | Plan | Execution time |
| --- | --- | --- |
| No index | Parallel sequential scan over 100,000 rows + hash anti join | 36.8 ms |
| HNSW index (`vector_cosine_ops`, `hnsw.ef_search = 100`) | Index scan, 50 of 50 rows returned | 3.9 ms |

The HNSW index makes the query about **9.4x faster**.

`hnsw.ef_search = 100` matters: with the default of 40, the index returns at most 40 candidates, so `LIMIT 50`
came back short once already-seen items were filtered out.

## Recommendation quality

Each synthetic user prefers category `id % 16`, so the share of recommendations in that category measures how well
the profile vector captures the user's taste. First 100 users, top 10 each (1,000 recommendations).
Reproduce with `psql "$DATABASE_URL" -f db/quality.sql`.

| Method | Top-10 hits in the user's preferred category | Query time |
| --- | --- | --- |
| Recommender (profile = average of liked vectors) | 100.00% | 147 ms |
| Random baseline (expected about 1/16 = 6.25%) | 5.00% | 2,284 ms |

The recommender is 20x better than random on this data.

**Caveat:** the synthetic categories are perfectly separated, so 100% validates that the pipeline works end to end
(profile, nearest neighbors, "already seen" filter). It does not predict quality on real content; real embeddings
(phase 2) would give a lower, more meaningful number.

## Tests

| Suite | Command | Result |
| --- | --- | --- |
| Rust unit tests (re-ranking: max per creator, limit, ordering, empty input) | `cd src && cargo test` | 4 passing |
| Node integration tests (recommendations, idempotent likes, validation) | `cd src/api && npm test` | 4 passing |

The Node suite runs against the real database and needs the Rust service running (`cargo run`).

## Environment notes

- Docker limits `/dev/shm` to 64 MB. The first parallel HNSW build failed with
  `could not resize shared memory segment ... No space left on device`; the postgres service now sets
  `shm_size: 512mb` (larger than `maintenance_work_mem = 256MB`).

## Pending

- Load test with k6 (day 8): throughput, p95/p99 latency and error rate of `GET /recommendations/:userId`.
