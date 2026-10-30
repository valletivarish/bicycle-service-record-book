import { Router } from 'express';
import { pool } from './db.js';
import { STATUSES, validateRecord } from './validation.js';

export const records = Router();

const COLUMNS = `id, bicycle_label AS "bicycleLabel", service_date AS "serviceDate",
  work_description AS "workDescription", parts_fitted AS "partsFitted", cost, status,
  created_at AS "createdAt", updated_at AS "updatedAt"`;

function parseId(req, res) {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1 || id > 2147483647) {
    res.status(400).json({ error: 'Record id must be a positive whole number.' });
    return null;
  }
  return id;
}

records.get('/', async (req, res) => {
  const where = [];
  const params = [];
  if (req.query.status) {
    if (!STATUSES.includes(req.query.status)) {
      return res.status(400).json({ error: 'Unknown status filter.' });
    }
    params.push(req.query.status);
    where.push(`status = $${params.length}`);
  }
  if (req.query.q !== undefined && (typeof req.query.q !== 'string' || req.query.q.length > 60)) {
    return res.status(400).json({ error: 'Search text must be at most 60 characters.' });
  }
  if (typeof req.query.q === 'string' && req.query.q.trim()) {
    params.push(`%${req.query.q.trim()}%`);
    where.push(`bicycle_label ILIKE $${params.length}`);
  }
  const filter = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const result = await pool.query(
    `SELECT ${COLUMNS} FROM service_records ${filter}
     ORDER BY service_date DESC, id DESC`,
    params,
  );
  res.json(result.rows);
});

records.get('/:id', async (req, res) => {
  const id = parseId(req, res);
  if (id === null) return;
  const result = await pool.query(`SELECT ${COLUMNS} FROM service_records WHERE id = $1`, [id]);
  if (result.rowCount === 0) return res.status(404).json({ error: 'Service record not found.' });
  res.json(result.rows[0]);
});

records.post('/', async (req, res) => {
  const { values, errors } = validateRecord(req.body);
  if (Object.keys(errors).length) return res.status(422).json({ errors });
  const result = await pool.query(
    `INSERT INTO service_records
       (bicycle_label, service_date, work_description, parts_fitted, cost, status)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING ${COLUMNS}`,
    [values.bicycleLabel, values.serviceDate, values.workDescription, values.partsFitted,
      values.cost, values.status],
  );
  res.status(201).json(result.rows[0]);
});

records.put('/:id', async (req, res) => {
  const id = parseId(req, res);
  if (id === null) return;
  const { values, errors } = validateRecord(req.body);
  if (Object.keys(errors).length) return res.status(422).json({ errors });
  const result = await pool.query(
    `UPDATE service_records
     SET bicycle_label = $1, service_date = $2, work_description = $3, parts_fitted = $4,
         cost = $5, status = $6, updated_at = now()
     WHERE id = $7 RETURNING ${COLUMNS}`,
    [values.bicycleLabel, values.serviceDate, values.workDescription, values.partsFitted,
      values.cost, values.status, id],
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Service record not found.' });
  res.json(result.rows[0]);
});

records.delete('/:id', async (req, res) => {
  const id = parseId(req, res);
  if (id === null) return;
  const result = await pool.query('DELETE FROM service_records WHERE id = $1', [id]);
  if (result.rowCount === 0) return res.status(404).json({ error: 'Service record not found.' });
  res.status(204).end();
});
