-- Datos sinteticos: 1,000 creadores, 10,000 usuarios, 100,000 contenidos, 20 likes por usuario.
-- Cada contenido tiene una categoria (0..15) y su vector es 1.0 en esa dimension + ruido.
-- Cada usuario prefiere la categoria (id % 16), lo que permite medir la calidad de las recomendaciones.

INSERT INTO creators (name) SELECT 'creator_' || g FROM generate_series(1, 1000) g;
INSERT INTO users    (name) SELECT 'user_'    || g FROM generate_series(1, 10000) g;

INSERT INTO content (creator_id, title, category, embedding)
SELECT 1 + floor(random() * 1000)::int,
       'post ' || g,
       x.cat,
       (SELECT array_agg((CASE WHEN d = x.cat THEN 1.0 ELSE 0.0 END) + random() * 0.3 ORDER BY d)
          FROM generate_series(0, 15) d)::vector
FROM generate_series(1, 100000) g
CROSS JOIN LATERAL (SELECT floor(random() * 16)::int + 0 * g AS cat) x;

INSERT INTO interactions (user_id, content_id, type)
SELECT u.id, c.id, 'like'
FROM users u
CROSS JOIN LATERAL (SELECT floor(random() * 90000)::int + 0 * u.id AS start) s
CROSS JOIN LATERAL (SELECT id FROM content
                    WHERE category = u.id % 16 AND id > s.start
                    ORDER BY id
                    LIMIT 20) c
ON CONFLICT DO NOTHING;

ANALYZE;
