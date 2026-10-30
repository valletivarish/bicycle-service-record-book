import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { pool } from './db.js';

const migrationsDir = fileURLToPath(new URL('../migrations/', import.meta.url));

// Applies every .sql file in migrations/ once, in file-name order. Each file
// runs in its own transaction, so a broken migration leaves no half-made schema.
export async function migrate() {
  await pool.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
    name TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  const done = await pool.query('SELECT name FROM schema_migrations');
  const applied = new Set(done.rows.map((row) => row.name));

  // Path is fixed by this module (../migrations), never from user input.
  // eslint-disable-next-line security/detect-non-literal-fs-filename
  const files = (await readdir(migrationsDir)).filter((f) => f.endsWith('.sql')).sort();
  for (const file of files) {
    if (applied.has(file)) continue;
    // file is a name returned by readdir of that same fixed folder.
    // eslint-disable-next-line security/detect-non-literal-fs-filename
    const sql = await readFile(migrationsDir + file, 'utf8');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
      await client.query('COMMIT');
      console.log(`applied migration ${file}`);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await migrate();
  await pool.end();
}
