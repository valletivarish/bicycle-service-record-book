import express from 'express';
import { pool } from './db.js';
import { records } from './records.js';

export const app = express();

app.use(express.json());

// Used by the CD smoke test and the CloudWatch health metric. It queries the
// database so "ok" means the whole path Nginx -> Node -> PostgreSQL works,
// and it reports which release (git commit) is running.
app.get('/api/health', async (req, res) => {
  const release = process.env.RELEASE_ID || 'local';
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', release });
  } catch {
    res.status(503).json({ status: 'database unavailable', release });
  }
});

app.use('/api/records', records);

app.use('/api', (req, res) => {
  res.status(404).json({ error: 'Not found.' });
});

// Express 5 forwards rejected promises from async routes to this handler.
app.use((err, req, res, next) => {
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Request body is not valid JSON.' });
  }
  console.error(err);
  res.status(500).json({ error: 'Something went wrong on the server.' });
});
