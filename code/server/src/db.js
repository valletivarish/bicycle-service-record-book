import { readFileSync } from 'node:fs';
import pg from 'pg';

// DATE columns come back as plain 'YYYY-MM-DD' strings. The default parser
// turns them into JS Dates at local midnight, which shifts the day in UTC.
pg.types.setTypeParser(pg.types.builtins.DATE, (value) => value);

// Connection details come from the standard PGHOST, PGUSER, PGPASSWORD and
// PGDATABASE variables (read by pg itself), so no connection URL holding a
// password is written in config files. DATABASE_URL is still accepted for
// the CI test database. With DB_SSL=true the RDS certificate is verified
// against the AWS CA bundle mounted into the container.
const ssl =
  process.env.DB_SSL === 'true'
    ? { ca: readFileSync('/certs/rds-ca.pem', 'utf8'), rejectUnauthorized: true }
    : undefined;

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl,
  max: 5,
});
