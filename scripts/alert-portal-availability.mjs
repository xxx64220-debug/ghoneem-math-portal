// GitHub Issues are the durable incident state. No email service, PAT or new secret.
import {readFileSync, appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {SERVICES, REPOSITORY, RECIPIENT, isTimestamp, validateReport, outcome} from './run-portal-availability.mjs';

const BOT = 'github-actions[bot]';
const prefix = (name, testMode = false) => `<!-- portal-availability:v1:${testMode ? 'test:' : ''}${name} `;
const recoveryPrefix = (number, testMode = false) => `<!-- portal-availability-recovery:v1:${testMode ? 'test:' : ''}${number} `;
const title = (name, testMode = false) => `[Availability${testMode ? ' TEST' : ''}] ${SERVICES[name]}`;

function parseMarker(body, marker) {
  if (!body?.startsWith(marker)) return null;
  const end = body.indexOf(' -->');
  try {
    const value = JSON.parse(body.slice(marker.length, end));
    if (end < 0 || !isTimestamp(value.checked_at) || !/^[1-9]\d*$/.test(value.run_id) ||
        !/^[1-9]\d*$/.test(value.attempt)) throw new Error();
    return {checked_at: value.checked_at, run_id: value.run_id, attempt: value.attempt};
  } catch { throw new Error('Incident state is damaged; refusing to create duplicate alerts'); }
}

export function runContext({repository = REPOSITORY, recipient = RECIPIENT, runId, attempt = '1', testMode = false} = {}) {
  if (repository !== REPOSITORY || recipient !== RECIPIENT ||
      !/^[1-9]\d*$/.test(String(runId)) || !/^[1-9]\d*$/.test(String(attempt)) || typeof testMode !== 'boolean') {
    throw new Error('Invalid availability alert context');
  }
  return {repository, recipient, testMode, run_id: String(runId), attempt: String(attempt),
    url: `https://github.com/${repository}/actions/runs/${runId}/attempts/${attempt}`};
}

function markerData(report, context) {
  return {checked_at: report.checked_at, run_id: context.run_id, attempt: context.attempt};
}
function evidence(service, report) {
  return [`Service: **${SERVICES[service.name]}**`, '',
    `First sample (UTC): ${report.samples[0].checked_at} — ${outcome(service.checks[0])}`,
    `Confirmation (UTC): ${report.checked_at} — ${outcome(service.checks[1])}`].join('\n');
}
export function failureBody(service, report, context) {
  return [prefix(service.name, context.testMode) + JSON.stringify(markerData(report, context)) + ' -->',
    `@${context.recipient} — ${context.testMode ? '**TEST ONLY: simulated failure; production services were not interrupted.**' : 'confirmed availability-check failure.'}`, '',
    evidence(service, report), '', `[Workflow run](${context.url})`, '',
    'The same service failed two bounded read-only probes with a 5-second pause between rounds. This is evidence from the GitHub runner; it does not establish impact for every user.',
    'Repeated failures stay in this issue without repeated mentions or comments. Recovery requires two healthy probes.',
    'No credentials, response bodies or student records are included.'].join('\n');
}
export function recoveryBody(issue, service, report, context) {
  return [recoveryPrefix(issue.number, context.testMode) + JSON.stringify(markerData(report, context)) + ' -->',
    `@${context.recipient} — ${context.testMode ? '**TEST ONLY: simulated recovery; notification test complete.**' : '**recovered** in both confirmation probes.'}`, '',
    evidence(service, report), '', `[Recovery workflow run](${context.url})`, '',
    'Recovery time is when the monitor observed healthy responses, not the exact end of user impact.'].join('\n');
}

// No automatic POST retries: a timeout may mean GitHub accepted the write.
// The next serialized run reads durable state before deciding whether to write.
export function githubClient({token, repository = REPOSITORY, fetchImpl = fetch, timeoutMs = 10000} = {}) {
  if (!token || repository !== REPOSITORY) throw new Error('Missing or invalid GitHub configuration');
  return async (method, suffix, body) => {
    if (!['GET', 'POST', 'PATCH'].includes(method) || !/^\/issues(?:[/?]|$)/.test(suffix)) {
      throw new Error('Unsupported GitHub operation');
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchImpl(`https://api.github.com/repos/${repository}${suffix}`, {
        method, redirect: 'error', signal: controller.signal,
        headers: {Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2026-03-10', 'Content-Type': 'application/json'},
        ...(body === undefined ? {} : {body: JSON.stringify(body)}),
      });
      if (!response.ok) throw new Error(`GitHub API HTTP ${response.status}`);
      return await response.json();
    } catch (error) {
      if (/^GitHub API HTTP [1-5]\d\d$/.test(error?.message)) throw error;
      throw new Error(controller.signal.aborted ? 'GitHub API timeout; delivery unknown' :
        'GitHub API request failed; delivery unknown');
    } finally { clearTimeout(timer); }
  };
}

async function listAll(request, suffix) {
  const values = [];
  for (let page = 1; page <= 20; page++) {
    const batch = await request('GET', `${suffix}${suffix.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
    if (!Array.isArray(batch)) throw new Error('Invalid GitHub state response');
    values.push(...batch);
    if (batch.length < 100) return values;
  }
  throw new Error('Incident history exceeds pagination bound; no further alerts changed');
}

export async function reconcile({report: input, context: inputContext, request, enabled = false}) {
  if (!enabled) return ['External alerts disabled; no GitHub API calls made.'];
  const context = runContext(inputContext);
  const report = validateReport(input);
  const issues = await listAll(request, '/issues?state=all&creator=github-actions%5Bbot%5D&sort=created&direction=desc');
  const notes = [];
  for (const service of report.services) {
    if (service.state === 'unconfirmed') { notes.push(`${service.name}: unconfirmed; unchanged`); continue; }
    const matching = issues.filter(issue => !issue.pull_request && issue.user?.login === BOT &&
      (issue.body?.startsWith(prefix(service.name, context.testMode)) || issue.title === title(service.name, context.testMode)))
      .sort((a, b) => b.number - a.number);
    if (matching.filter(issue => issue.state === 'open').length > 1) {
      throw new Error('Multiple open incidents for one service; manual review required');
    }
    const latest = matching[0];
    let incident, recovered;
    if (latest) {
      incident = parseMarker(latest.body, prefix(service.name, context.testMode));
      if (!incident || !Number.isSafeInteger(latest.number) || !['open', 'closed'].includes(latest.state)) {
        throw new Error('Incident state is damaged; refusing to create duplicate alerts');
      }
      const comments = await listAll(request, `/issues/${latest.number}/comments`);
      recovered = comments.filter(comment => comment.user?.login === BOT)
        .map(comment => parseMarker(comment.body, recoveryPrefix(latest.number, context.testMode))).find(Boolean);
      const newestTime = recovered?.checked_at ?? incident.checked_at;
      if (Date.parse(report.checked_at) < Date.parse(newestTime) ||
          (recovered && report.checked_at === newestTime && service.state === 'failed')) {
        notes.push(`${service.name}: stale report; unchanged`); continue;
      }
    }
    if (service.state === 'failed') {
      if (latest && !recovered) {
        // Manual closure does not reset suppression during the same outage.
        if (latest.state === 'closed') await request('PATCH', `/issues/${latest.number}`, {state: 'open'});
        notes.push(`${service.name}: existing incident #${latest.number}; no repeated mention`);
      } else {
        if (latest?.state === 'open') await request('PATCH', `/issues/${latest.number}`, {state: 'closed', state_reason: 'completed'});
        const created = await request('POST', '/issues', {title: title(service.name, context.testMode), body: failureBody(service, report, context)});
        notes.push(`${service.name}: opened incident #${created.number}`);
      }
    } else if (latest) {
      // Comment before closing. Lost responses reconcile from this marker next run.
      if (!recovered) await request('POST', `/issues/${latest.number}/comments`, {body: recoveryBody(latest, service, report, context)});
      if (latest.state === 'open') await request('PATCH', `/issues/${latest.number}`, {state: 'closed', state_reason: 'completed'});
      notes.push(`${service.name}: recovered; incident #${latest.number} closed`);
    } else notes.push(`${service.name}: healthy; no incident`);
  }
  return notes;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const enabled = process.env.PORTAL_AVAILABILITY_ALERTS_ENABLED === 'true';
    let notes;
    if (!enabled) notes = ['External alerts disabled; no GitHub API calls made.'];
    else {
      if (process.env.GITHUB_REF !== 'refs/heads/main' ||
          !['schedule', 'push', 'workflow_dispatch'].includes(process.env.GITHUB_EVENT_NAME)) {
        throw new Error('Alerts are restricted to trusted main-branch runs');
      }
      const context = {repository: process.env.GITHUB_REPOSITORY,
        recipient: process.env.PORTAL_AVAILABILITY_RECIPIENT,
        runId: process.env.GITHUB_RUN_ID, attempt: process.env.GITHUB_RUN_ATTEMPT};
      runContext(context);
      const report = JSON.parse(readFileSync(process.argv[2], 'utf8'));
      notes = await reconcile({enabled, report, context, request: githubClient({token: process.env.GITHUB_TOKEN})});
    }
    console.log(notes.join('\n'));
    if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, '\n### Alert delivery\n\n' + notes.map(note => `- ${note}`).join('\n') + '\n');
  } catch {
    console.error('Availability alert processing failed. Delivery is unverified; inspect the health summary and GitHub issue state before retrying.');
    process.exitCode = 1;
  }
}
