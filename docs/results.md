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

## Load test (k6)

`GET /recommendations/:userId` through the whole path: Node API -> Rust service -> PostgreSQL + pgvector (HNSW index).
Random user per request. Each run sends a **fixed** number of requests per second for 30 s
(`constant-arrival-rate`), so it measures one load level. Reproduce with `k6 run -e RATE=400 loadtest/k6.js`
(Rust built with `--release`, Node with `LOG_LEVEL=warn`).

Targets from the original requirements: p95 < 150 ms, p99 < 200 ms, errors < 0.1%.

| Requested rate | Achieved | p50 | p95 | p99 | Max | Errors | Dropped | Targets met |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 100 req/s | 100 req/s | 5.6 ms | 7.5 ms | 9.6 ms | 15 ms | 0% | 0 | Yes |
| 200 req/s | 200 req/s | 5.4 ms | 8.2 ms | 11.3 ms | 51 ms | 0% | 0 | Yes |
| **400 req/s** | **400 req/s** | **5.9 ms** | **10.7 ms** | **19.3 ms** | 47 ms | **0%** | 0 | **Yes** |
| 600 req/s | 600 req/s | 7.9 ms | 94.9 ms | 235.9 ms | 365 ms | 0% | 0 | No (p99) |
| 800 req/s | 797 req/s | 17.7 ms | 111.4 ms | 280.7 ms | 408 ms | 0% | 0 | No (p99) |
| 1,000 req/s | 615 req/s | 345 ms | 608 ms | 28.7 s | 30 s | 1.13% | 3,322 | No (all) |

**Findings**

- **Capacity within targets: 400 req/s**, with p99 of 19.3 ms (10x below the 200 ms target).
- **Tail latency degrades first.** Between 400 and 600 req/s the median barely moves (5.9 -> 7.9 ms) but p99 jumps
  from 19 ms to 236 ms: requests start to queue.
- **Saturation point: about 800 req/s.** At 800 req/s every request is still served without errors, only slower.
- **Collapse at 1,000 req/s.** Throughput *drops* to 615 req/s (below the 800 req/s run), latency reaches 30 s,
  k6 cannot start 3,322 requests (`dropped_iterations`), and 1.13% fail with `dial: i/o timeout`
  (new TCP connections are not accepted in time). This is congestion collapse: past saturation, more load means
  less useful work.
- **Not profiled yet:** which process (Node, Rust or PostgreSQL) saturates first. Next step: watch CPU per process
  during the 600 and 800 req/s runs.

**Caveat:** k6, Node, Rust and PostgreSQL run on the same laptop inside Docker Desktop, so they compete for CPU.
These numbers compare load levels on this machine; they are not a production capacity estimate. The original target
of 2,000 req/s belongs to the AWS deployment (phase 2).

## AWS deployment (phase 2)

Same code on AWS (`us-east-1`): API Gateway HTTP API -> Rust Lambda (arm64, 256 MB, `DB_MAX_CONNECTIONS=2`) ->
RDS PostgreSQL 17 + pgvector 0.8.1 on `db.t4g.micro` (2 vCPU, 1 GB), no RDS Proxy. k6 ran from a laptop in Sonora,
Mexico, so every request includes the round trip to Virginia. Lambda and RDS numbers come from CloudWatch
(`scripts/aws-metrics.sh`). Measured on November 6, 2026.

### Single requests

| What | Result |
| --- | --- |
| Nearest-neighbor query on RDS (`db/explain.sql`) | 4.7 ms (3.9 ms on the laptop) |
| Node Lambda cold start (`/health`, one `curl`) | 2.08 s |
| Rust Lambda cold start (`/recommendations/42`) | 0.93 s |
| Rust Lambda warm, end to end from Mexico | 0.29 s (the Lambda itself: 18.7 ms) |
| Memory used | Rust Lambda 17 MB, Node Lambda 130 MB |

### Load test (`GET /recommendations/:userId`, 30 s per step, after a 10 req/s warm-up)

| Requested | Achieved | p50 | p95 | p99 | Errors | Lambda avg duration | Max concurrent Lambdas | Max RDS connections | Max RDS CPU |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 25 req/s | 25 req/s | 120 ms | 168 ms | 220 ms | 0% | 14-25 ms | 10 | 18 | 5% |
| 50 req/s | 50 req/s | 104 ms | 132 ms | 166 ms | 0% | 14 ms | 15 | 18 | 6% |
| 100 req/s | 99 req/s | 102 ms | 120 ms | 199 ms | 0% | 14 ms | 13 | 25 | 8% |
| 200 req/s | 149 req/s | 3.12 s | 6.25 s | 6.35 s | 60% | 523 ms -> 2,203 ms | **400 (account limit)** | 34 -> 70 -> 206 | 12% -> 54% |
| 300 req/s | 261 req/s | 211 ms | 3.17 s | 3.22 s | 50% | 1,332 ms | 400 | 206 | 54% |

**Findings**

- **Healthy up to 100 req/s.** The Rust Lambda runs in about 14 ms; the ~100 ms seen by k6 is almost all network
  between Mexico and Virginia. 15 concurrent Lambdas and 8% RDS CPU were enough.
- **Connection storm at 200 req/s.** Scaling out creates new Lambda instances, and each one opens its own TLS
  connections to PostgreSQL. On a 2 vCPU instance that is slow, so requests pile up, Lambda creates even more
  instances, which open even more connections. Lambda duration jumped from 14 ms to 2.2 s (p99 ~3.4 s, matching the
  3 s pool `acquire_timeout`), concurrency hit the account limit of 400, Lambda throttled 582 invocations, 6,214
  invocations failed, and RDS reached 206 connections.
- **The database CPU was not the bottleneck** (54% at the worst point); connection management was.
- **Laptop vs Lambda.** Locally, one long-lived process with a pool of 10 connections handled 400 req/s within
  targets. On Lambda every instance is a separate process with its own pool, so connections grow with concurrency.
  This is the problem **RDS Proxy** solves (a shared pool in front of the database), which was left out for cost.

**What would fix it, in order of impact:** RDS Proxy; reserved concurrency on the Rust Lambda (for example 20) so it
fails fast instead of flooding the database; provisioned concurrency to avoid cold starts at traffic spikes; a larger
RDS instance.

## Environment notes

- Docker limits `/dev/shm` to 64 MB. The first parallel HNSW build failed with
  `could not resize shared memory segment ... No space left on device`; the postgres service now sets
  `shm_size: 512mb` (larger than `maintenance_work_mem = 256MB`).

