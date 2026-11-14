// Reuse the existing read-only probes; never log response bodies or headers.
import {checkAvailability} from './check-portal-availability.mjs';
import {writeFileSync, renameSync, appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

export const SERVICES = Object.freeze({
  portal: 'Public mathematics portal',
  auth: 'Supabase Authentication',
  database: 'Read-only database endpoint',
});
export const REPOSITORY = 'xxx64220-debug/ghoneem-math-portal';
export const RECIPIENT = 'xxx64220-debug';
export const isTimestamp = value => typeof value === 'string' &&
  /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value) &&
  Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value;

function invalid() { throw new Error('Invalid or incomplete availability report'); }
function sanitizeSample(sample) {
  if (!sample || !isTimestamp(sample.checked_at) || !Array.isArray(sample.checks) ||
      sample.checks.length !== 3) invalid();
  const checks = Object.keys(SERVICES).map(name => {
    const matches = sample.checks.filter(check => check.name === name);
    if (matches.length !== 1) invalid();
    const check = matches[0];
    if (typeof check.ok !== 'boolean' || !Number.isInteger(check.elapsed_ms) ||
        check.elapsed_ms < 0 || check.elapsed_ms > 120000) invalid();
    const safe = {name, ok: check.ok, elapsed_ms: check.elapsed_ms};
    if (Number.isInteger(check.status) && check.status >= 100 && check.status <= 599) {
      if (check.error !== undefined) invalid();
      const denial = check.expected_access_denied === true;
      if (denial && !(name === 'database' && [401, 403].includes(check.status))) invalid();
      if (check.ok !== ((check.status >= 200 && check.status < 300) || denial)) invalid();
      safe.status = check.status;
      if (denial) safe.expected_access_denied = true;
    } else {
      if (check.status !== undefined || check.ok || check.expected_access_denied ||
          !['timeout', 'connection_error'].includes(check.error)) invalid();
      safe.error = check.error;
    }
    return safe;
  });
  return {checked_at: sample.checked_at, checks};
}

// Recompute all decisions from an allowlist; extra fields never reach GitHub.
export function validateReport(value) {
  if (value?.version !== 1 || !Array.isArray(value.samples) || value.samples.length !== 2) invalid();
  const samples = value.samples.map(sanitizeSample);
  const gap = Date.parse(samples[1].checked_at) - Date.parse(samples[0].checked_at);
  if (gap < 0 || gap > 120000) invalid();
  const services = Object.keys(SERVICES).map((name, index) => {
    const checks = samples.map(sample => sample.checks[index]);
    return {name, state: checks.every(check => check.ok) ? 'healthy' :
      checks.every(check => !check.ok) ? 'failed' : 'unconfirmed', checks};
  });
  return {version: 1, samples, checked_at: samples[1].checked_at, services,
    // Preserve the original CLI's red result if the final check is unsuccessful.
    ok: samples[1].checks.every(check => check.ok)};
}

export async function collectReport({fetchImpl = fetch, timeoutMs = 8000,
  pause = ms => new Promise(resolve => setTimeout(resolve, ms))} = {}) {
  const first = await checkAvailability({fetchImpl, timeoutMs});
  // Confirm recovery too. A single good response cannot close an incident.
  await pause(5000);
  const second = await checkAvailability({fetchImpl, timeoutMs});
  return validateReport({version: 1, samples: [first, second]});
}

export function outcome(check) {
  if (check.error === 'timeout') return 'timeout (8-second deadline)';
  if (check.error === 'connection_error') return 'connection error';
  return `HTTP ${check.status}${check.expected_access_denied ? ' (expected access denial; healthy)' : ''}`;
}

export function reportSummary(report) {
  return ['## Portal availability', '', `Detection time (UTC): ${report.checked_at}`, '',
    '| Service | First sample | Confirmation | Decision |', '| --- | --- | --- | --- |',
    ...report.services.map(service => `| ${SERVICES[service.name]} | ${outcome(service.checks[0])} | ${outcome(service.checks[1])} | ${service.state} |`), '',
    'Failed = the same service failed both samples. Unconfirmed = mixed results; no incident transition.',
    'Healthy = both samples succeeded. Database access remains restricted. No student records were requested.', ''].join('\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const report = await collectReport();
    const destination = process.argv[2];
    if (!destination) throw new Error('Missing report destination');
    writeFileSync(`${destination}.tmp`, JSON.stringify(report) + '\n', {mode: 0o600});
    renameSync(`${destination}.tmp`, destination);
    console.log(JSON.stringify(report));
    if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, reportSummary(report));
    if (!report.ok) process.exitCode = 1;
  } catch {
    console.error('Availability measurement failed; no complete report. This is a monitoring error, not evidence of a service outage.');
    process.exitCode = 1;
  }
}
