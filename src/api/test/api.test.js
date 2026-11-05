// Integration tests: they call the real app against the real database (and the Rust service).
// Run with the dev container services up and the Rust service running (cargo run).
import { expect, use } from 'chai';
import chaiHttp, { request } from 'chai-http';

import { app } from '../app.js';
import { pool } from '../db.js';

use(chaiHttp);

describe('GET /recommendations/:userId', () => {
  it('returns 10 personalized items for a user with likes', async () => {
    const res = await request.execute(app).get('/recommendations/42');

    expect(res).to.have.status(200);
    expect(res.body.strategy).to.equal('personalized');
    expect(res.body.items).to.be.an('array').with.lengthOf(10);
  });

  it('returns 400 for an invalid user id', async () => {
    const res = await request.execute(app).get('/recommendations/abc');

    expect(res).to.have.status(400);
  });
});

describe('POST /interactions', () => {
  // Test data: user 1 and a content item user 1 has not interacted with yet.
  const userId = 1;
  let contentId;

  before(async () => {
    const { rows } = await pool.query(
      `SELECT c.id FROM content c
       WHERE NOT EXISTS (SELECT 1 FROM interactions i WHERE i.user_id = $1 AND i.content_id = c.id)
       ORDER BY c.id LIMIT 1`,
      [userId],
    );
    contentId = rows[0].id;
  });

  after(async () => {
    // Leave the database as it was.
    await pool.query('DELETE FROM interactions WHERE user_id = $1 AND content_id = $2', [userId, contentId]);
  });

  it('creates the like once and does not duplicate it when repeated', async () => {
    const body = { userId, contentId, type: 'like' };

    const first = await request.execute(app).post('/interactions').send(body);
    const second = await request.execute(app).post('/interactions').send(body);

    expect(first).to.have.status(201);
    expect(second).to.have.status(200);
    expect(second.body.created).to.equal(false);

    const { rows } = await pool.query(
      `SELECT count(*)::int AS n FROM interactions WHERE user_id = $1 AND content_id = $2 AND type = 'like'`,
      [userId, contentId],
    );
    expect(rows[0].n).to.equal(1);
  });

  it('returns 400 when the body is invalid', async () => {
    const res = await request.execute(app).post('/interactions').send({ userId: 'abc', type: 'love' });

    expect(res).to.have.status(400);
    expect(res.body.details).to.have.property('userId');
  });
});

// Close the connection pool so Mocha can exit when the tests finish.
after(() => pool.end());