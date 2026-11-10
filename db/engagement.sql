-- A/B test results: recommended feed vs chronological feed.
-- Run: psql "$DATABASE_URL" -f db/engagement.sql

-- One row per impression, with whether the user clicked (view) or liked it after seeing it.
CREATE TEMP VIEW impression_outcomes AS
SELECT f.variant,
       f.user_id,
       f.position,
       EXISTS (SELECT 1 FROM interactions i
               WHERE i.user_id = f.user_id AND i.content_id = f.content_id
                 AND i.type = 'view' AND i.created_at >= f.created_at) AS clicked,
       EXISTS (SELECT 1 FROM interactions i
               WHERE i.user_id = f.user_id AND i.content_id = f.content_id
                 AND i.type = 'like' AND i.created_at >= f.created_at) AS liked
FROM feed_impressions f;

-- CTR and like rate per variant.
SELECT variant,
       count(DISTINCT user_id)                    AS users,
       count(*)                                   AS impressions,
       sum(clicked::int)                          AS clicks,
       round(100.0 * avg(clicked::int), 2)        AS ctr_pct,
       round(100.0 * avg(liked::int), 2)          AS like_rate_pct
FROM impression_outcomes
GROUP BY variant
ORDER BY variant;

-- Lift: how much higher the recommended CTR is than the chronological CTR.
SELECT round(100.0 * (avg(clicked::int) FILTER (WHERE variant = 'recommended')
                    / NULLIF(avg(clicked::int) FILTER (WHERE variant = 'chronological'), 0) - 1), 1)
       AS ctr_lift_pct
FROM impression_outcomes;

-- CTR by position in the feed (users click less as they scroll down).
SELECT position,
       round(100.0 * avg(clicked::int) FILTER (WHERE variant = 'recommended'), 1)   AS recommended_ctr_pct,
       round(100.0 * avg(clicked::int) FILTER (WHERE variant = 'chronological'), 1) AS chronological_ctr_pct
FROM impression_outcomes
GROUP BY position
ORDER BY position;
