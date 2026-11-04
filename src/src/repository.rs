use pgvector::Vector;
use sqlx::PgPool;

use crate::models::Recommendation;

/// The user's taste profile: the average vector of the content they liked or shared.
/// Returns `None` when the user has no likes yet (cold start).
pub async fn user_profile(db: &PgPool, user_id: i32) -> Result<Option<Vector>, sqlx::Error> {
    sqlx::query_scalar(
        "SELECT AVG(c.embedding)
         FROM interactions i
         JOIN content c ON c.id = i.content_id
         WHERE i.user_id = $1 AND i.type IN ('like', 'share')",
    )
    .bind(user_id)
    .fetch_one(db)
    .await
}

/// The `limit` content items closest to the profile (cosine distance), excluding what the user already saw.
pub async fn nearest_unseen(
    db: &PgPool,
    user_id: i32,
    profile: &Vector,
    limit: i64,
) -> Result<Vec<Recommendation>, sqlx::Error> {
    // SET LOCAL only lasts for this transaction, so it must run on the same connection as the query.
    // Without it, the HNSW index (day 7) returns at most 40 rows.
    let mut tx = db.begin().await?;
    sqlx::query("SET LOCAL hnsw.ef_search = 100")
        .execute(&mut *tx)
        .await?;

    let rows = sqlx::query_as::<_, Recommendation>(
        "SELECT c.id, c.creator_id, c.title, 1 - (c.embedding <=> $2) AS score
         FROM content c
         WHERE NOT EXISTS (SELECT 1 FROM interactions i
                           WHERE i.user_id = $1 AND i.content_id = c.id)
         ORDER BY c.embedding <=> $2
         LIMIT $3",
    )
    .bind(user_id)
    .bind(profile)
    .bind(limit)
    .fetch_all(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(rows)
}

/// Cold start: most liked content in the last 24 hours, then all-time as a tiebreaker.
/// `score` here is the number of likes, not a similarity.
pub async fn trending(db: &PgPool, limit: i64) -> Result<Vec<Recommendation>, sqlx::Error> {
    sqlx::query_as::<_, Recommendation>(
        "SELECT c.id, c.creator_id, c.title, count(i.content_id)::float8 AS score
         FROM content c
         JOIN interactions i ON i.content_id = c.id AND i.type = 'like'
         GROUP BY c.id
         ORDER BY count(*) FILTER (WHERE i.created_at > now() - interval '24 hours') DESC,
                  count(*) DESC
         LIMIT $1",
    )
    .bind(limit)
    .fetch_all(db)
    .await
}
