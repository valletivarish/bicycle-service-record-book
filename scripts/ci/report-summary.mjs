// Usage: node scripts/ci/report-summary.mjs <tool> <report-file> <tool-version>
// Reads one tool report, writes a short table to the job Summary page and the
// log, and exits 1 when that tool's gate fails. Each gate is listed in GATES.
import { appendFileSync, existsSync, readFileSync } from 'node:fs';

const [tool, file, version = 'unknown'] = process.argv.slice(2);
const SEVERITIES = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN'];

const GATES = {
  eslint: 'any lint problem',
  'node-test': 'any failed or skipped test',
  'npm-audit': 'HIGH or CRITICAL advisory',
  osv: 'HIGH or CRITICAL advisory',
  semgrep: 'any ERROR or WARNING rule match',
  trufflehog: 'any secret found',
  checkov: 'any failed check',
  trivy: 'HIGH or CRITICAL with a fix available',
};

function bySeverity(list) {
  const counts = Object.fromEntries(SEVERITIES.map((s) => [s, 0]));
  for (const severity of list) counts[SEVERITIES.includes(severity) ? severity : 'UNKNOWN'] += 1;
  return counts;
}

function cvssToSeverity(score) {
  const value = Number(score);
  if (!score || Number.isNaN(value)) return 'UNKNOWN';
  if (value >= 9) return 'CRITICAL';
  if (value >= 7) return 'HIGH';
  if (value >= 4) return 'MEDIUM';
  return 'LOW';
}

// Each parser returns { counts, failed, details } where details are short
// one-line descriptions of the findings for the log.
const parsers = {
  eslint(text) {
    const messages = JSON.parse(text).flatMap((f) =>
      f.messages.map((m) => `${f.filePath.split('/code/').pop()}:${m.line} ${m.ruleId}`),
    );
    const counts = { problems: messages.length };
    return { counts, failed: messages.length > 0, details: messages };
  },
  'node-test'(text) {
    const total = (text.match(/<testcase /g) || []).length;
    const failures = (text.match(/<failure/g) || []).length;
    const skipped = (text.match(/<skipped/g) || []).length;
    const counts = { tests: total, passed: total - failures - skipped, failed: failures, skipped };
    return { counts, failed: total === 0 || failures + skipped > 0, details: [] };
  },
  'npm-audit'(text) {
    const report = JSON.parse(text);
    const v = report.metadata.vulnerabilities;
    const counts = { CRITICAL: v.critical, HIGH: v.high, MEDIUM: v.moderate, LOW: v.low };
    const details = Object.values(report.vulnerabilities || {}).map(
      (p) => `${p.name} ${p.severity} (${p.range})`,
    );
    return { counts, failed: v.critical + v.high > 0, details };
  },
  osv(text) {
    const groups = [];
    for (const result of JSON.parse(text).results || []) {
      for (const pkg of result.packages) {
        for (const group of pkg.groups || []) {
          groups.push({ name: `${pkg.package.name}@${pkg.package.version}`, group });
        }
      }
    }
    const severities = groups.map((g) => cvssToSeverity(g.group.max_severity));
    const counts = bySeverity(severities);
    const details = groups.map((g, i) => `${g.name} ${g.group.ids.join(',')} ${severities[i]}`);
    return { counts, failed: counts.CRITICAL + counts.HIGH > 0, details };
  },
  semgrep(text) {
    const results = JSON.parse(text).results;
    const counts = { ERROR: 0, WARNING: 0, INFO: 0 };
    for (const r of results) counts[r.extra.severity] = (counts[r.extra.severity] || 0) + 1;
    const details = results.map((r) => `${r.path}:${r.start.line} ${r.check_id.split('.').pop()} ${r.extra.severity}`);
    return { counts, failed: counts.ERROR + counts.WARNING > 0, details };
  },
  trufflehog(text) {
    const found = text.split('\n').filter((line) => line.trim().startsWith('{'));
    const details = found.map((line) => {
      const r = JSON.parse(line);
      return `${r.DetectorName} verified=${r.Verified} ${JSON.stringify(r.SourceMetadata?.Data?.Git?.file || '')}`;
    });
    return { counts: { secrets: found.length }, failed: found.length > 0, details };
  },
  checkov(text) {
    // One framework gives an object, several give an array.
    const reports = [JSON.parse(text)].flat();
    const failedChecks = reports.flatMap((r) => r.results?.failed_checks || []);
    const passed = reports.reduce((n, r) => n + (r.summary?.passed || 0), 0);
    const skipped = reports.reduce((n, r) => n + (r.summary?.skipped || 0), 0);
    const counts = { passed, failed: failedChecks.length, skipped };
    const details = failedChecks.map((c) => `${c.check_id} ${c.resource} (${c.file_path.replace(/^\//, '')})`);
    return { counts, failed: failedChecks.length > 0, details };
  },
  trivy(text) {
    const vulns = (JSON.parse(text).Results || []).flatMap((r) => r.Vulnerabilities || []);
    const counts = bySeverity(vulns.map((v) => v.Severity));
    const details = vulns.map((v) => `${v.PkgName} ${v.InstalledVersion} ${v.VulnerabilityID} ${v.Severity}`);
    return { counts, failed: counts.CRITICAL + counts.HIGH > 0, details };
  },
};

if (!parsers[tool]) {
  console.error(`unknown tool ${tool}`);
  process.exit(2);
}

let result;
if (!existsSync(file)) {
  result = { counts: { report: 'missing' }, failed: true, details: [] };
} else {
  result = parsers[tool](readFileSync(file, 'utf8'));
}

const findings = Object.entries(result.counts)
  .map(([key, value]) => `${key}: ${value}`)
  .join(', ');
const verdict = result.failed ? 'FAIL' : 'PASS';
const lines = [
  '| Tool | Version | Findings | Gate | Result |',
  '|---|---|---|---|---|',
  `| ${tool} | ${version} | ${findings} | ${GATES[tool]} | **${verdict}** |`,
  '',
];
if (result.details.length) {
  lines.push('<details><summary>Findings</summary>', '');
  for (const d of result.details.slice(0, 40)) lines.push(`- \`${d}\``);
  if (result.details.length > 40) lines.push(`- ... ${result.details.length - 40} more in the artifact`);
  lines.push('', '</details>', '');
}

const markdown = lines.join('\n');
console.log(markdown);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown + '\n');
process.exit(result.failed ? 1 : 0);
