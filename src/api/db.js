// PostgreSQL connection pool, shared by the whole app (like a singleton DbContext factory in .NET).
import pg from 'pg';

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  max: Number(process.env.DB_MAX_CONNECTIONS ?? 10),
  connectionTimeoutMillis: 3000, // fail fast if the database is down
});