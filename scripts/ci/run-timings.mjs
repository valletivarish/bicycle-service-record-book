// Usage: node scripts/ci/run-timings.mjs <label> <run-id>... > timings.json
// Pulls run and job timestamps from the GitHub API (through the gh CLI) for
// the CI/CD optimisation comparison. Queue time is kept apart from execution:
//   queue    = run created -> first job started (waiting for runners)
//   wall     = first job started -> last job finished (what the pipeline took)
//   jobMins  = sum of each executed job's own duration (billed runner time)
import { execFileSync } from 'node:child_process';

const [label, ...ids] = process.argv.slice(2);
const api = (path) => JSON.parse(execFileSync('gh', ['api', path], { encoding: 'utf8' }));
const repo =
  process.env.GITHUB_REPOSITORY ||
  execFileSync('gh', ['repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner'], {
    encoding: 'utf8',
  }).trim();
const seconds = (a, b) => (new Date(b) - new Date(a)) / 1000;

const rows = ids.map((id) => {
  const run = api(`repos/${repo}/actions/runs/${id}`);
  const jobs = api(`repos/${repo}/actions/runs/${id}/jobs?per_page=50`).jobs;
  const ran = jobs.filter((j) => j.conclusion !== 'skipped' && j.started_at && j.completed_at);
  const ci = ran.filter((j) => j.name.startsWith('CI:'));
  const firstStart = ran.map((j) => j.started_at).sort()[0];
  const lastEnd = ci.map((j) => j.completed_at).sort().at(-1);
  return {
    label,
    runId: Number(id),
    event: run.event,
    commit: run.head_sha.slice(0, 7),
    conclusion: run.conclusion,
    queueSeconds: seconds(run.created_at, firstStart),
    // CD only fails fast while AWS is not configured, so CI wall time is the
    // comparable figure; job minutes include the short CD job when it ran.
    ciWallSeconds: seconds(firstStart, lastEnd),
    jobMinutes: Number((ran.reduce((n, j) => n + seconds(j.started_at, j.completed_at), 0) / 60).toFixed(2)),
    executedJobs: ran.map((j) => `${j.name} (${seconds(j.started_at, j.completed_at)}s, ${j.conclusion})`),
    skippedJobs: jobs.filter((j) => j.conclusion === 'skipped').map((j) => j.name),
  };
});

console.log(JSON.stringify(rows, null, 2));
