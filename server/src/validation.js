export const STATUSES = [
  'Booked in',
  'In progress',
  'Waiting for parts',
  'Ready for collection',
  'Collected',
];

// The repair desk is in Ireland, so "today" is the Dublin calendar date, not
// the UTC date of the server (they differ for an hour after midnight in summer).
export function todayInDublin(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Dublin' }).format(now);
}

function isRealDate(text) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return false;
  const parsed = new Date(`${text}T00:00:00Z`);
  // 2026-02-30 parses to 2 March, so the round trip catches impossible days.
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === text;
}

// Returns { values, errors }. Cost is kept as a string ("45.50") so the
// amount reaches PostgreSQL NUMERIC without passing through a float.
export function validateRecord(body, today = todayInDublin()) {
  const errors = {};
  const input = body && typeof body === 'object' ? body : {};

  const bicycleLabel = typeof input.bicycleLabel === 'string' ? input.bicycleLabel.trim() : '';
  if (!bicycleLabel) errors.bicycleLabel = 'Bicycle label is required.';
  else if (bicycleLabel.length > 60) errors.bicycleLabel = 'Bicycle label must be 60 characters or fewer.';

  const workDescription =
    typeof input.workDescription === 'string' ? input.workDescription.trim() : '';
  if (!workDescription) errors.workDescription = 'Work description is required.';
  else if (workDescription.length > 2000) {
    errors.workDescription = 'Work description must be 2000 characters or fewer.';
  }

  const serviceDate = typeof input.serviceDate === 'string' ? input.serviceDate : '';
  if (!isRealDate(serviceDate)) errors.serviceDate = 'Service date must be a valid date.';
  else if (serviceDate > today) errors.serviceDate = 'Service date cannot be in the future.';

  let cost = input.cost === undefined || input.cost === null || input.cost === '' ? '0' : input.cost;
  cost = String(cost).trim();
  if (cost.startsWith('-')) errors.cost = 'Cost cannot be negative.';
  // Two plain patterns instead of an optional group, so the check has no
  // nested quantifier (flagged by eslint-plugin-security as unsafe regex).
  else if (!/^\d{1,6}$/.test(cost) && !/^\d{1,6}\.\d{1,2}$/.test(cost)) {
    errors.cost = 'Cost must be an amount like 45 or 45.50 (up to 999999.99).';
  }

  const status = input.status === undefined ? 'Booked in' : input.status;
  if (!STATUSES.includes(status)) errors.status = `Status must be one of: ${STATUSES.join(', ')}.`;

  return {
    values: { bicycleLabel, serviceDate, workDescription, cost, status },
    errors,
  };
}
