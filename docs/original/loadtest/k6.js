import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<300'],
    http_req_failed: ['rate<0.01'],
  },
  stages: [
    { duration: '5m', target: 2000 },
    { duration: '10m', target: 2000 },
    { duration: '5m', target: 0 },
  ],
};

export default function () {
  let res = http.get('http://localhost:4566/restapis/');
  check(res, { 'status was 200': (r) => r.status === 200 });
  sleep(1);
}
