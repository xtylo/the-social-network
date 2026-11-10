-- Engagement measurement (phase 3): what the feed showed to each user, to compute click-through rate (CTR).
-- A click is a 'view' interaction on an item after it was shown.

CREATE TABLE feed_impressions (
  id         bigserial   PRIMARY KEY,
  user_id    int         NOT NULL REFERENCES users(id),
  content_id int         NOT NULL REFERENCES content(id),
  position   smallint    NOT NULL,  -- 1 = top of the feed
  variant    text        NOT NULL CHECK (variant IN ('recommended', 'chronological')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX feed_impressions_user_content_idx ON feed_impressions (user_id, content_id);
