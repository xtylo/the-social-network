// Load test for GET /recommendations/:userId, the hot path of the feed (Node API -> Rust -> pgvector).
// Each run sends a FIXED number of requests per second, so it measures one load level:
//   k6 run -e RATE=200 loadtest/k6.js
// Options: RATE (requests/s, default 100), DURATION (default 30s), BASE_URL (default http://localhost:3000).
import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const RATE = Number(__ENV.RATE || 100);
const DURATION = __ENV.DURATION || '30s';
const USERS = 10000; // users created by db/02_seed.sql

export const options = {
  scenarios: {
    recommendations: {
      // constant-arrival-rate: k6 starts RATE requests every second no matter how slow the server is.
      // If the server cannot keep up, k6 reports "dropped_iterations" (requests it could not even start).
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: Math.ceil(Math.max(50, RATE / 2)),
      maxVUs: Math.ceil(Math.max(200, RATE * 2)),
    },
  },
  // Targets from the original requirements. A failed threshold marks the run as failed but it still completes.
  thresholds: {
    http_req_duration: ['p(95)<150', 'p(99)<200'],
    http_req_failed: ['rate<0.001'],
  },
  summaryTrendStats: ['avg', 'p(50)', 'p(95)', 'p(99)', 'max'],
};

export default function () {
  // A different random user each time, so we do not measure a single cached query.
  const userId = 1 + Math.floor(Math.random() * USERS);
  const res = http.get(`${BASE_URL}/recommendations/${userId}`, {
    tags: { name: 'GET /recommendations/:userId' },
  });
  check(res, { 'status is 200': (r) => r.status === 200 });
}