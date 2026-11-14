// Explicitly requested delivery drill. Uses synthetic reports, never live probes.
// Test incident markers and titles are isolated from production incidents.
import {appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {validateReport, REPOSITORY, RECIPIENT} from './run-portal-availability.mjs';
import {reconcile, githubClient} from './alert-portal-availability.mjs';

function syntheticReport(failed, checkedAt) {
  return validateReport({version: 1, samples: [-5000, 0].map(offset => ({
    checked_at: new Date(Date.parse(checkedAt) + offset).toISOString(),
    checks: ['portal', 'auth', 'database'].map(name => ({
      name, ok: !(failed && name === 'auth'), status: failed && name === 'auth' ? 503 : 200, elapsed_ms: 1,
    })),
  }))});
}

export async function testDelivery({enabled = false, request, context,
  now = () => new Date().toISOString(), pause = ms => new Promise(resolve => setTimeout(resolve, ms))} = {}) {
  if (!enabled) return ['External alerts disabled; delivery drill skipped.'];
  const writes = [];
  const auditedRequest = async (method, path, body) => {
    if (method !== 'GET') writes.push({method, path});
    return request(method, path, body);
  };
  const input = {enabled: true, context: {...context, testMode: true}, request: auditedRequest};
  const failed = syntheticReport(true, now());
  const failureNotes = await reconcile({...input, report: failed});
  const afterFailure = writes.length;
  await reconcile({...input, report: failed});
  if (writes.length !== afterFailure) throw new Error('Duplicate test failure notification');
  await pause(5000);
  const healthy = syntheticReport(false, now());
  const recoveryNotes = await reconcile({...input, report: healthy});
  const afterRecovery = writes.length;
  await reconcile({...input, report: healthy});
  if (writes.length !== afterRecovery) throw new Error('Duplicate test recovery notification');
  return ['TEST ONLY — synthetic failure/recovery; no live probes were performed.',
    ...failureNotes, 'Repeated failure: zero additional writes.',
    ...recoveryNotes, 'Repeated recovery: zero additional writes.',
    `Test API mutations: ${writes.length}. GitHub accepted the changes; personal inbox/device receipt is not verified.`];
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const enabled = process.env.PORTAL_AVAILABILITY_ALERTS_ENABLED === 'true';
    let notes;
    if (!enabled) notes = await testDelivery();
    else {
      if (process.env.GITHUB_REPOSITORY !== REPOSITORY || process.env.GITHUB_REF !== 'refs/heads/main' ||
          !['push', 'workflow_dispatch'].includes(process.env.GITHUB_EVENT_NAME)) throw new Error('Untrusted delivery drill');
      notes = await testDelivery({enabled, request: githubClient({token: process.env.GITHUB_TOKEN}),
        context: {repository: REPOSITORY, recipient: RECIPIENT,
          runId: process.env.GITHUB_RUN_ID, attempt: process.env.GITHUB_RUN_ATTEMPT}});
    }
    console.log(notes.join('\n'));
    if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY,
      '\n### Synthetic notification delivery test\n\n' + notes.map(note => `- ${note}`).join('\n') + '\n');
  } catch {
    console.error('Synthetic alert delivery test failed. Inspect test issue state before rerunning; production incidents were not changed by the test.');
    process.exitCode = 1;
  }
}
