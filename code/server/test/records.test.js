import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';
import request from 'supertest';
import { app } from '../src/app.js';
import { pool } from '../src/db.js';
import { migrate } from '../src/migrate.js';
import { todayInDublin, validateRecord } from '../src/validation.js';

const valid = {
  bicycleLabel: 'BK-0142 blue hybrid',
  serviceDate: '2026-09-14',
  workDescription: 'Replaced rear brake pads and trued the front wheel.',
  cost: '45.50',
  status: 'In progress',
};

before(async () => {
  await migrate();
});

beforeEach(async () => {
  await pool.query('TRUNCATE service_records RESTART IDENTITY');
});

after(async () => {
  await pool.end();
});

describe('service record CRUD', () => {
  test('creates, reads, updates and deletes a record', async () => {
    const created = await request(app).post('/api/records').send(valid).expect(201);
    assert.equal(created.body.bicycleLabel, valid.bicycleLabel);
    assert.equal(created.body.serviceDate, '2026-09-14');
    assert.equal(created.body.cost, '45.50');

    const id = created.body.id;
    const read = await request(app).get(`/api/records/${id}`).expect(200);
    assert.equal(read.body.workDescription, valid.workDescription);

    const updated = await request(app)
      .put(`/api/records/${id}`)
      .send({ ...valid, status: 'Collected', cost: '60' })
      .expect(200);
    assert.equal(updated.body.status, 'Collected');
    assert.equal(updated.body.cost, '60.00');
    assert.equal(updated.body.bicycleLabel, valid.bicycleLabel);

    await request(app).delete(`/api/records/${id}`).expect(204);
    await request(app).get(`/api/records/${id}`).expect(404);
  });

  test('lists newest service first and filters by status and label', async () => {
    await request(app).post('/api/records').send({ ...valid, serviceDate: '2026-01-05' });
    await request(app)
      .post('/api/records')
      .send({ ...valid, bicycleLabel: 'BK-0200 red road', serviceDate: '2026-03-01', status: 'Collected' });

    const all = await request(app).get('/api/records').expect(200);
    assert.deepEqual(all.body.map((r) => r.serviceDate), ['2026-03-01', '2026-01-05']);

    const collected = await request(app).get('/api/records?status=Collected').expect(200);
    assert.equal(collected.body.length, 1);
    assert.equal(collected.body[0].bicycleLabel, 'BK-0200 red road');

    const search = await request(app).get('/api/records?q=hybrid').expect(200);
    assert.equal(search.body.length, 1);

    await request(app).get('/api/records?status=Lost').expect(400);
  });

  test('defaults cost to zero and status to Booked in', async () => {
    const res = await request(app)
      .post('/api/records')
      .send({ bicycleLabel: 'BK-1', serviceDate: '2026-02-02', workDescription: 'Safety check' })
      .expect(201);
    assert.equal(res.body.cost, '0.00');
    assert.equal(res.body.status, 'Booked in');
  });
});

describe('validation and errors', () => {
  test('rejects missing label and description with 422 and saves nothing', async () => {
    const res = await request(app)
      .post('/api/records')
      .send({ ...valid, bicycleLabel: '  ', workDescription: '' })
      .expect(422);
    assert.ok(res.body.errors.bicycleLabel);
    assert.ok(res.body.errors.workDescription);
    const list = await request(app).get('/api/records');
    assert.equal(list.body.length, 0);
  });

  test('rejects negative, malformed and over-precise costs', async () => {
    for (const cost of ['-1', '12.345', 'ten', '1e3']) {
      const res = await request(app).post('/api/records').send({ ...valid, cost }).expect(422);
      assert.ok(res.body.errors.cost, `cost ${cost} should be rejected`);
    }
  });

  test('rejects impossible and future service dates', async () => {
    for (const serviceDate of ['2026-02-30', '14/09/2026', '2999-01-01']) {
      const res = await request(app)
        .post('/api/records')
        .send({ ...valid, serviceDate })
        .expect(422);
      assert.ok(res.body.errors.serviceDate);
    }
  });

  test('rejects a status outside the allowed list', async () => {
    const res = await request(app)
      .post('/api/records')
      .send({ ...valid, status: 'Lost' })
      .expect(422);
    assert.ok(res.body.errors.status);
  });

  test('update with invalid data leaves the stored record unchanged', async () => {
    const { body } = await request(app).post('/api/records').send(valid);
    await request(app).put(`/api/records/${body.id}`).send({ ...valid, cost: '-5' }).expect(422);
    const read = await request(app).get(`/api/records/${body.id}`);
    assert.equal(read.body.cost, '45.50');
  });

  test('returns 404 for a missing record and 400 for a bad id', async () => {
    await request(app).get('/api/records/999').expect(404);
    await request(app).put('/api/records/999').send(valid).expect(404);
    await request(app).delete('/api/records/999').expect(404);
    await request(app).get('/api/records/abc').expect(400);
  });

  test('returns 400 for a body that is not JSON', async () => {
    await request(app)
      .post('/api/records')
      .set('Content-Type', 'application/json')
      .send('{"bicycleLabel":')
      .expect(400);
  });
});

describe('health and dates', () => {
  test('health reports ok and the release id', async () => {
    const res = await request(app).get('/api/health').expect(200);
    assert.equal(res.body.status, 'ok');
    assert.equal(res.body.release, process.env.RELEASE_ID || 'local');
    assert.equal(res.headers['x-powered-by'], undefined);
  });

  test('today is taken from the Dublin calendar, not UTC', () => {
    // 23:30 UTC on 30 June is already 1 July in Dublin (UTC+1 in summer).
    assert.equal(todayInDublin(new Date('2026-06-30T23:30:00Z')), '2026-07-01');
    const { errors } = validateRecord({ ...valid, serviceDate: '2026-07-01' }, '2026-06-30');
    assert.ok(errors.serviceDate);
  });
});
