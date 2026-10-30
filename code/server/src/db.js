import pg from 'pg';

// DATE columns come back as plain 'YYYY-MM-DD' strings. The default parser
// turns them into JS Dates at local midnight, which shifts the day in UTC.
pg.types.setTypeParser(pg.types.builtins.DATE, (value) => value);

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  max: 5,
});
