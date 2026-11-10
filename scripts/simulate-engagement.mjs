// Simulates users browsing their feed, to exercise the engagement pipeline: impressions -> clicks -> CTR.
// Usage (from the repo root): node scripts/simulate-engagement.mjs [users=1000] [baseUrl=http://localhost:3000]
//
// Synthetic behavior (an ASSUMPTION, not real data): a user clicks an item with 30% probability when it matches their
// preferred category (userId % 16) and 3% otherwise, a bit less for each position lower in the feed. After a click,
// they like the item with 40% (match) or 10% (no match) probability.

const USERS = Number(process.argv[2] ?? 1000);
const BASE_URL = process.argv[3] ?? process.env.BASE_URL ?? 'http://localhost:3000';
const CONCURRENCY = 20; // users browsing at the same time

const CLICK = { match: 0.3, other: 0.03 };
const LIKE = { match: 0.4, other: 0.1 };
const POSITION_DECAY = 0.05; // -5% click probability per position below the top

const stats = {
  recommended: { users: 0, impressions: 0, clicks: 0, likes: 0 },
  chronological: { users: 0, impressions: 0, clicks: 0, likes: 0 },
  errors: 0,
};

async function interact(userId, contentId, type) {
  const res = await fetch(`${BASE_URL}/interactions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId, contentId, type }),
  });
  if (!res.ok) stats.errors++;
}

async function simulateUser(userId) {
  const res = await fetch(`${BASE_URL}/feed/${userId}`);
  if (!res.ok) {
    stats.errors++;
    return;
  }
  const feed = await res.json();
  const variant = stats[feed.variant];
  const preferred = userId % 16;
  variant.users++;

  for (const item of feed.items) {
    variant.impressions++;
    const match = item.category === preferred;
    const clickChance = (match ? CLICK.match : CLICK.other) * (1 - POSITION_DECAY * (item.position - 1));
    if (Math.random() < clickChance) {
      variant.clicks++;
      await interact(userId, item.id, 'view');
      if (Math.random() < (match ? LIKE.match : LIKE.other)) {
        variant.likes++;
        await interact(userId, item.id, 'like');
      }
    }
  }
}

// A small worker pool: CONCURRENCY users at a time until all are done.
let next = 1;
async function worker() {
  while (next <= USERS) {
    const userId = next++;
    await simulateUser(userId);
  }
}

const started = Date.now();
await Promise.all(Array.from({ length: CONCURRENCY }, worker));
const seconds = ((Date.now() - started) / 1000).toFixed(1);

console.log(`Simulated ${USERS} users against ${BASE_URL} in ${seconds} s (errors: ${stats.errors})`);
for (const name of ['recommended', 'chronological']) {
  const v = stats[name];
  const ctr = v.impressions ? ((100 * v.clicks) / v.impressions).toFixed(2) : '0.00';
  console.log(`${name.padEnd(14)} users=${v.users} impressions=${v.impressions} clicks=${v.clicks} likes=${v.likes} CTR=${ctr}%`);
}
console.log('Authoritative numbers come from the database: psql "$DATABASE_URL" -f db/engagement.sql');
