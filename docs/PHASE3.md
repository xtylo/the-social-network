# Phase 3: Engagement and 2,000 req/s (3 days)

Close the two most valuable gaps left from the [original requirements](original-requirements.md), in **3 sessions of
1 hour each**:

1. **Engagement measurement.** The original "impact" (+$300K/month, 2M interactions) was never measurable. Replace it
   with a real pipeline: log what the feed shows (impressions) and what users click, assign users to an A/B test
   (recommended feed vs chronological feed), and compute click-through rate (CTR) per variant.
2. **2,000 req/s on AWS.** The original target. Phase 2 reached 300 req/s after fixing the connection storm.

Out of scope (documented as next steps): real embeddings, Prometheus/Grafana, UI and usability tests.

## Progress

| Day | Topic | Status |
| --- | --- | --- |
| 13 | Engagement: impressions, A/B feed, CTR, simulated users (local) | Done |
| 14 | Redeploy on AWS sized for 2,000 req/s | Done |
| 15 | Ramp to 2,000 req/s, results, `terraform destroy` | Pending |

## Findings

- **AWS Free plan limits RDS sizes.** `db.t4g.xlarge` failed with `FreeTierRestrictionError`; `db.t4g.small`
  (2 vCPU, 2 GB) was accepted. The micro, small and medium classes all have 2 vCPU, so the 2,000 req/s test runs on
  the same CPU as phase 2, with more memory for connections.
- **Load data first, index second.** On RDS the seed took 2.1 s for 100,000 content items and 6.0 s for 200,000 likes,
  and the HNSW index was built afterwards in 36.4 s (about 45 s in total). In phase 2, with the index created before
  the seed, loading took several minutes because the graph was updated row by row.
- **Parallel HNSW builds need shared memory.** With `maintenance_work_mem = 512MB`, the build failed on the 2 GB
  instance (`could not resize shared memory segment ... Cannot allocate memory`). Building without parallel workers
  (`max_parallel_maintenance_workers = 0`, 256 MB) worked.

## Day 13: Engagement measurement (local, 60 min)

**Design**

- `feed_impressions` table: every item the feed shows (user, content, position, variant, time).
- `GET /feed/:userId` (Node): assigns the variant by `userId % 2`. Variant `recommended` calls the Rust service;
  variant `chronological` returns the newest unseen content. Both log their impressions.
- A **click** is the existing `view` interaction (`POST /interactions`).
- `db/engagement.sql`: CTR and likes per impression, per variant.
- `scripts/simulate-engagement.js`: synthetic users browse their feed and click with a higher probability when an item
  matches their hidden taste.

**Honest limit:** the simulated users click according to the same category signal the recommender uses, so the
recommender is expected to win. The deliverable is the **measurement pipeline** (instrumentation, A/B assignment,
metrics), which would produce real numbers with real users.

- [x] (10 min) `db/03_engagement.sql` with `feed_impressions`; apply it to the local database.
- [x] (20 min) `GET /feed/:userId` in Node with A/B assignment and impression logging.
- [x] (15 min) Simulation of 1,000 users against the local API.
- [x] (10 min) CTR per variant with `db/engagement.sql`; record the result.
- [x] (5 min) Commit.

**Done when:** CTR per variant is computed from logged impressions and clicks.

**Result:** recommended CTR 23.71% vs chronological 3.68% (+544.6% lift); details in [results.md](results.md#engagement-ab-test-phase-3).

## Day 14: AWS sized for 2,000 req/s (60 min, mostly waiting)

| Setting | Phase 2 | Phase 3 | Why |
| --- | --- | --- | --- |
| RDS instance | `db.t4g.micro` (2 vCPU, 1 GB) | `db.t4g.small` (2 vCPU, 2 GB) | 4 vCPU was planned, but the AWS Free plan rejects larger classes (`FreeTierRestrictionError`); 2 GB allows ~180 connections for 100 Lambdas |
| Rust Lambda reserved concurrency | 25 | 100 | 2,000 req/s x ~20 ms is about 40 concurrent instances |
| API Gateway stage limit | 300 req/s | 3,000 req/s | Stay above the target |
| Seed | Index created before loading | Index created after loading | Building HNSW once is much faster than row by row |

- [x] (10 min) Terraform variables for the sizes above; rebuild both Lambda zips.
- [x] (15 min) `terraform apply` (RDS takes 5 to 10 minutes).
- [x] (20 min) Load schema, seed, then create the HNSW index; apply `03_engagement.sql`.
- [x] (10 min) Smoke test: `/recommendations/42`. (`/feed` stays local: on AWS the Node Lambda cannot call the Rust
  service without a NAT Gateway or a Lambda VPC endpoint, both paid.)
- [x] (5 min) Commit.

**Done when:** the API answers on AWS with the larger database.

## Day 15: Ramp to 2,000 req/s and teardown (60 min)

- [ ] (25 min) k6 from the laptop: warm up, then 500, 1,000, 1,500 and 2,000 req/s (30 s each). Watch throttles,
  concurrency, RDS CPU and connections with `scripts/aws-metrics.sh`.
- [ ] (15 min) Results in `docs/results.md` and the README.
- [ ] (15 min) **`terraform destroy`**, check that nothing is left, delete the access key.
- [ ] (5 min) Commit.

**Done when:** the 2,000 req/s result is documented (met or not, with the reason) and nothing is left running.

**Note:** k6 runs from a laptop in Mexico, so latency includes about 100 ms of network. The error rate and the
throughput are the meaningful numbers; p99 < 200 ms would need a load generator inside AWS (next step).

## Rules

- Same as phase 2: never leave AWS running between sessions without a reason; `terraform destroy` is never cut.
- If day 13 runs long, cut the simulation size, not the metrics query.
