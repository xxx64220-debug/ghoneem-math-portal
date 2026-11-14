import {test, before, after} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {checkAvailability} from '../scripts/check-portal-availability.mjs';
import {collectReport, validateReport, reportSummary, REPOSITORY, RECIPIENT} from '../scripts/run-portal-availability.mjs';
import {reconcile, githubClient, runContext} from '../scripts/alert-portal-availability.mjs';
import {testDelivery} from '../scripts/test-portal-alert-delivery.mjs';

// Any accidentally unmocked network request fails the test immediately.
const realFetch = globalThis.fetch;
before(() => { globalThis.fetch = () => { throw new Error('External network forbidden in availability tests'); }; });
after(() => { globalThis.fetch = realFetch; });
const names = ['portal', 'auth', 'database'];
const bot = {login: 'github-actions[bot]'};
const context = {repository: REPOSITORY, recipient: RECIPIENT, runId: '123456', attempt: '1'};
const stamp = seconds => new Date(Date.UTC(2026, 10, 14, 20, 0, seconds)).toISOString();
function fixture(first = {}, second = first, seconds = 0) {
  return validateReport({version: 1, samples: [first, second].map((overrides, index) => ({
    checked_at: stamp(seconds + index * 5), checks: names.map(name => {
      const value = overrides[name] ?? 200;
      return {name, ok: value === 200, elapsed_ms: 10,
        ...(typeof value === 'number' ? {status: value} : {error: value})};
    }),
  }))});
}
function fakeGitHub(initial = []) {
  const issues = structuredClone(initial), comments = new Map(), calls = [];
  let next = Math.max(0, ...issues.map(issue => issue.number)) + 1;
  let failAfter, failBefore;
  const request = async (method, path, body) => {
    calls.push({method, path, body: structuredClone(body)});
    if (failBefore?.(method, path)) { failBefore = null; throw new Error('simulated API failure'); }
    const url = new URL('https://example.invalid' + path);
    let result;
    if (method === 'GET') {
      const match = url.pathname.match(/^\/issues\/(\d+)\/comments$/);
      const direct = url.pathname.match(/^\/issues\/(\d+)$/);
      if (direct) return structuredClone({...issues.find(issue => issue.number === Number(direct[1])), comments: (comments.get(Number(direct[1])) ?? []).length});
      const list = match ? (comments.get(Number(match[1])) ?? []) : [...issues].sort((a, b) => b.number - a.number);
      const page = Number(url.searchParams.get('page') ?? 1);
      result = structuredClone(list.slice((page - 1) * 100, page * 100));
    } else if (method === 'POST' && path === '/issues') {
      result = {...structuredClone(body), number: next++, state: 'open', user: bot}; issues.push(result);
    } else if (method === 'POST') {
      const number = Number(path.split('/')[2]);
      result = {...structuredClone(body), id: calls.length, user: bot};
      comments.set(number, [...(comments.get(number) ?? []), result]);
    } else if (method === 'PATCH') {
      result = issues.find(issue => issue.number === Number(path.split('/')[2]));
      Object.assign(result, body);
    } else throw new Error('Unexpected fake operation');
    if (failAfter?.(method, path)) { failAfter = null; throw new Error('simulated lost response after accepted write'); }
    return structuredClone(result);
  };
  return {issues, comments, calls, request,
    writes: () => calls.filter(call => call.method !== 'GET'),
    failAfter: condition => { failAfter = condition; }, failBefore: condition => { failBefore = condition; }};
}
const apply = (db, report, extra = {}) => reconcile({enabled: true, context, report, request: db.request, ...extra});

test('healthy probes keep GET-only endpoints, zero-row database query and no student authentication', async () => {
  const calls = [];
  const result = await checkAvailability({fetchImpl: async (url, options) => {
    calls.push({url, options}); return new Response('[]', {status: 200});
  }});
  assert.equal(result.ok, true); assert.equal(calls.length, 3);
  assert.match(calls[0].url, /^https:\/\/math\.portal\.ghoneem\.com\/$/);
  assert.match(calls[1].url, /\/auth\/v1\/health$/);
  assert.match(calls[2].url, /\/rest\/v1\/tracks\?select=id&limit=0$/);
  for (const {options} of calls) {
    assert.equal(options.method ?? 'GET', 'GET'); assert.equal(options.body, undefined);
    assert.equal(options.headers.Authorization, undefined); assert.equal(options.redirect, 'error');
    assert.equal(options.cache, 'no-store'); assert.ok(options.signal);
  }
});
for (const status of [401, 403]) test(`only exact database permission denial is healthy (HTTP ${status})`, async () => {
  const denied = JSON.stringify({code: '42501', message: 'permission denied for table tracks'});
  const result = await checkAvailability({fetchImpl: async url => new Response(denied, {status: url.includes('/rest/') ? status : 200})});
  assert.equal(result.ok, true); assert.equal(result.checks[2].expected_access_denied, true);
  const wrong = await checkAvailability({fetchImpl: async () => new Response(JSON.stringify({code: '42501', message: 'invalid key'}), {status})});
  assert.equal(wrong.ok, false); assert.ok(wrong.checks.every(check => !check.ok));
});
test('request timeout is bounded and emits no raw exception details', async () => {
  const start = Date.now();
  const result = await checkAvailability({timeoutMs: 15, fetchImpl: async (_url, {signal}) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(new Error('sensitive transport detail')));
  })});
  assert.ok(Date.now() - start < 1000); assert.ok(result.checks.every(check => check.error === 'timeout'));
  assert.doesNotMatch(JSON.stringify(result), /sensitive/);
});
test('body consumption also stays inside the probe deadline', async () => {
  const result = await checkAvailability({timeoutMs: 15, fetchImpl: async (_url, {signal}) => ({ok: true, status: 200,
    arrayBuffer: () => new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(new Error('body stalled')))),
  })});
  assert.ok(result.checks.every(check => check.error === 'timeout'));
});
test('connection errors and HTTP 503 stay sanitized', async () => {
  const result = await checkAvailability({fetchImpl: async url => {
    if (url.includes('/auth/')) throw new Error('token=TEST_SECRET student=TEST_NAME');
    return new Response('TEST_SECRET TEST_NAME', {status: 503});
  }});
  assert.equal(result.checks[1].error, 'connection_error');
  assert.doesNotMatch(JSON.stringify(result), /TEST_SECRET|TEST_NAME/);
});
test('runner takes exactly two rounds with one 5-second pause and uses the real probe logic', async () => {
  let calls = 0; const pauses = [];
  const result = await collectReport({fetchImpl: async () => { calls++; return new Response('[]'); }, pause: async ms => { pauses.push(ms); }});
  assert.equal(calls, 6); assert.deepEqual(pauses, [5000]); assert.equal(result.ok, true);
  assert.ok(result.services.every(service => service.state === 'healthy'));
});
test('transient failure then healthy does not open an incident', async () => {
  const db = fakeGitHub(); const report = fixture({auth: 503}, {});
  await apply(db, report); assert.equal(report.ok, true); assert.equal(db.writes().length, 0);
});
test('failures of different services across rounds cannot confirm an outage', async () => {
  const db = fakeGitHub(); const report = fixture({portal: 503}, {auth: 503});
  await apply(db, report); assert.equal(report.ok, false); assert.equal(db.writes().length, 0);
});
test('confirmed HTTP failure creates one issue with recipient, status, times and workflow link', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  assert.equal(db.issues.length, 1); const body = db.issues[0].body;
  assert.match(body, /@xxx64220-debug/); assert.match(body, /Supabase Authentication/);
  assert.match(body, /HTTP 503/); assert.match(body, /2026-11-14T20:00:05.000Z/);
  assert.match(body, /\/actions\/runs\/123456\/attempts\/1/);
  assert.equal(db.writes().length, 1);
});
test('persistent failure and repeated processing produce no duplicate writes', async () => {
  const db = fakeGitHub(); const report = fixture({auth: 503});
  await apply(db, report); await apply(db, report); await apply(db, fixture({auth: 'timeout'}, undefined, 60));
  assert.equal(db.writes().length, 1); assert.equal(db.issues.length, 1);
});
test('two healthy rounds produce one recovery comment and close, then remain silent', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  await apply(db, fixture({}, {}, 60)); await apply(db, fixture({}, {}, 120));
  assert.equal(db.issues[0].state, 'closed'); assert.equal(db.comments.get(1).length, 1);
  assert.match(db.comments.get(1)[0].body, /@xxx64220-debug.*recovered/);
  assert.equal(db.writes().length, 3);
});
test('one healthy sample cannot falsely recover an incident', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  await apply(db, fixture({auth: 503}, {}, 60));
  assert.equal(db.issues[0].state, 'open'); assert.equal(db.writes().length, 1);
});
test('a new failure after recovery starts a new incident', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  await apply(db, fixture({}, {}, 60)); await apply(db, fixture({auth: 'timeout'}, undefined, 120));
  assert.equal(db.issues.length, 2); assert.equal(db.issues[1].state, 'open');
  assert.match(db.issues[1].body, /timeout \(8-second deadline\)/);
});
test('multiple failing services recover independently', async () => {
  const db = fakeGitHub(); await apply(db, fixture({portal: 502, auth: 'connection_error', database: 503}));
  assert.equal(db.issues.length, 3);
  await apply(db, fixture({database: 503}, undefined, 60));
  assert.deepEqual(db.issues.map(issue => issue.state), ['closed', 'closed', 'open']);
});
test('accepted issue creation with a lost response is not retried or duplicated', async () => {
  const db = fakeGitHub(); db.failAfter((method, path) => method === 'POST' && path === '/issues');
  await assert.rejects(apply(db, fixture({auth: 503})), /lost response/);
  await apply(db, fixture({auth: 503}, undefined, 60)); assert.equal(db.issues.length, 1); assert.equal(db.writes().length, 1);
});
test('accepted recovery comment with a lost response is not duplicated', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  db.failAfter((method, path) => method === 'POST' && path.endsWith('/comments'));
  await assert.rejects(apply(db, fixture({}, {}, 60)), /lost response/);
  await apply(db, fixture({}, {}, 120));
  assert.equal(db.comments.get(1).length, 1); assert.equal(db.issues[0].state, 'closed');
});
test('failed recovery close resumes without another mention', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  db.failBefore(method => method === 'PATCH'); await assert.rejects(apply(db, fixture({}, {}, 60)));
  await apply(db, fixture({}, {}, 120)); assert.equal(db.comments.get(1).length, 1); assert.equal(db.issues[0].state, 'closed');
});
test('new failure after interrupted recovery closes the old incident and creates a new one', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  db.failBefore(method => method === 'PATCH'); await assert.rejects(apply(db, fixture({}, {}, 60)));
  await apply(db, fixture({auth: 503}, undefined, 120));
  assert.equal(db.issues.length, 2); assert.deepEqual(db.issues.map(issue => issue.state), ['closed', 'open']);
});
test('manually closed unresolved incident reopens without a new issue or mention', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503})); db.issues[0].state = 'closed';
  await apply(db, fixture({auth: 503}, undefined, 60));
  assert.equal(db.issues.length, 1); assert.equal(db.issues[0].state, 'open');
  assert.equal(db.writes().filter(call => call.method === 'POST').length, 1);
});
test('stale failure cannot reopen a recovered incident and stale health cannot close a newer one', async () => {
  const db = fakeGitHub(); const failure = fixture({auth: 503}, undefined, 60);
  await apply(db, failure); await apply(db, fixture({}, {}, 0)); assert.equal(db.issues[0].state, 'open');
  await apply(db, fixture({}, {}, 120)); const count = db.writes().length;
  await apply(db, failure); assert.equal(db.writes().length, count); assert.equal(db.issues[0].state, 'closed');
});
test('pagination finds the existing incident beyond the first page', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  for (let i = 0; i < 100; i++) db.issues.push({number: i + 1000, title: 'Unrelated bot issue', body: '', state: 'closed', user: bot});
  const count = db.writes().length; await apply(db, fixture({auth: 503}, undefined, 60));
  assert.equal(db.writes().length, count); assert.ok(db.calls.some(call => call.path.includes('page=2')));
});
test('malformed/incomplete reports cause no GitHub reads or false recovery', async () => {
  for (const report of [{}, {version: 1, samples: []}, {version: 1, samples: [fixture().samples[0], {checked_at: stamp(5), checks: []}]}]) {
    const db = fakeGitHub(); await assert.rejects(apply(db, report), /Invalid or incomplete/); assert.equal(db.calls.length, 0);
  }
});
test('extra report fields cannot inject credentials, response bodies or additional mentions', async () => {
  const db = fakeGitHub(); const report = fixture({auth: 503});
  report.token = 'TEST_SECRET'; report.samples[0].checks[1].body = '@everyone TEST_STUDENT';
  report.samples[1].checks[1].headers = {Authorization: 'TEST_SECRET'};
  await apply(db, report);
  assert.doesNotMatch(JSON.stringify(db.writes()), /TEST_SECRET|TEST_STUDENT|@everyone/);
  assert.doesNotMatch(reportSummary(validateReport(report)), /TEST_SECRET|TEST_STUDENT/);
});
test('a corrupt owned incident stops instead of opening duplicates', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503})); db.issues[0].body = 'damaged';
  await assert.rejects(apply(db, fixture({auth: 503}, undefined, 60)), /damaged/); assert.equal(db.issues.length, 1);
});
test('human-authored issues and pull requests are not mutated', async () => {
  const seed = fakeGitHub(); await apply(seed, fixture({auth: 503}));
  const db = fakeGitHub([{...seed.issues[0], number: 10, user: {login: 'someone'}}, {...seed.issues[0], number: 11, pull_request: {}}]);
  await apply(db, fixture({auth: 503}, undefined, 60));
  assert.equal(db.issues.length, 3); assert.ok(db.writes().every(call => call.path === '/issues'));
});
test('alerts disabled by default make zero API calls even without report/context', async () => {
  const db = fakeGitHub(); await reconcile({request: db.request}); assert.equal(db.calls.length, 0);
});
test('repository, recipient and workflow URL inputs cannot expand the audience or inject Markdown', () => {
  for (const patch of [{repository: 'other/repo'}, {recipient: 'other-user'}, {runId: '1) @everyone'}, {attempt: '../evil'}]) {
    assert.throws(() => runContext({...context, ...patch}), /Invalid/);
  }
});
test('API errors omit response bodies and transport details, never automatically retry writes', async () => {
  let calls = 0;
  const denied = githubClient({token: 'TEST_SECRET', fetchImpl: async (_url, options) => {
    calls++; assert.equal(options.redirect, 'error'); return new Response('TEST_SECRET', {status: 403});
  }});
  await assert.rejects(denied('POST', '/issues', {body: 'safe'}), /^Error: GitHub API HTTP 403$/); assert.equal(calls, 1);
  const broken = githubClient({token: 'TEST_SECRET', fetchImpl: async () => { throw new Error('TEST_SECRET'); }});
  await assert.rejects(broken('GET', '/issues'), /^Error: GitHub API request failed; delivery unknown$/);
});
test('API timeout is bounded and sanitized', async () => {
  const client = githubClient({token: 'TEST_SECRET', timeoutMs: 15, fetchImpl: async (_url, {signal}) =>
    new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(new Error('TEST_SECRET'))))});
  await assert.rejects(client('GET', '/issues'), /^Error: GitHub API timeout; delivery unknown$/);
});
test('healthy startup creates no issues or recovery messages', async () => {
  const db = fakeGitHub(); await apply(db, fixture()); assert.equal(db.writes().length, 0);
});
test('lost closing response does not produce another recovery comment', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  db.failAfter(method => method === 'PATCH'); await assert.rejects(apply(db, fixture({}, {}, 60)));
  await apply(db, fixture({}, {}, 120)); assert.equal(db.comments.get(1).length, 1);
  assert.equal(db.writes().length, 3);
});
test('invalid status, forged denial and inconsistent times cannot resolve an incident', async () => {
  const cases = [report => { report.samples[0].checks[0].status = 999; },
    report => { report.samples[0].checks[0].expected_access_denied = true; },
    report => { report.samples[1].checked_at = stamp(-5); },
    report => { report.samples[1].checked_at = stamp(300); }];
  for (const mutate of cases) {
    const db = fakeGitHub(); const report = fixture(); mutate(report);
    await assert.rejects(apply(db, report), /Invalid or incomplete/); assert.equal(db.calls.length, 0);
  }
});
test('state read failure cannot be mistaken for an empty incident history', async () => {
  const db = fakeGitHub(); db.failBefore(method => method === 'GET');
  await assert.rejects(apply(db, fixture({auth: 503}))); assert.equal(db.writes().length, 0);
});
test('CLI stays disabled with no configuration and rejects untrusted refs before any network', () => {
  const script = new URL('../scripts/alert-portal-availability.mjs', import.meta.url);
  const disabled = spawnSync(process.execPath, [script.pathname], {encoding: 'utf8', env: {}});
  assert.equal(disabled.status, 0); assert.match(disabled.stdout, /disabled/);
  const untrusted = spawnSync(process.execPath, [script.pathname], {encoding: 'utf8', env: {
    PORTAL_AVAILABILITY_ALERTS_ENABLED: 'true', GITHUB_REF: 'refs/heads/other', GITHUB_EVENT_NAME: 'push',
  }});
  assert.equal(untrusted.status, 1); assert.doesNotMatch(untrusted.stderr, /TEST_SECRET/);
});
test('synthetic delivery drill creates one labelled test issue, one recovery and no duplicate writes', async () => {
  const db = fakeGitHub(); let count = 0; const pauses = [];
  const notes = await testDelivery({enabled: true, request: db.request, context,
    now: () => stamp(120 + count++ * 60), pause: async ms => { pauses.push(ms); }});
  assert.equal(db.issues.length, 1); assert.equal(db.issues[0].state, 'closed');
  assert.match(db.issues[0].title, /Availability TEST/); assert.match(db.issues[0].body, /TEST ONLY: simulated failure/);
  assert.match(db.comments.get(1)[0].body, /TEST ONLY: simulated recovery/);
  assert.equal(db.writes().length, 3); assert.deepEqual(pauses, [5000]);
  assert.ok(notes.includes('Repeated failure: zero additional writes.'));
  assert.ok(notes.includes('Repeated recovery: zero additional writes.'));
});
test('synthetic healthy/failing reports cannot touch a genuine incident', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503}));
  let count = 0;
  await testDelivery({enabled: true, request: db.request, context,
    now: () => stamp(120 + count++ * 60), pause: async () => {}});
  assert.equal(db.issues.length, 2); assert.equal(db.issues[0].state, 'open');
  assert.equal(db.comments.get(1), undefined); assert.equal(db.issues[1].state, 'closed');
});
test('production recovery ignores test incidents', async () => {
  const db = fakeGitHub();
  await apply(db, fixture({auth: 503}), {context: {...context, testMode: true}});
  await apply(db, fixture({}, {}, 60));
  assert.equal(db.issues[0].state, 'open'); assert.equal(db.writes().length, 1);
});
test('disabled delivery drill performs no API request or waiting', async () => {
  const db = fakeGitHub();
  await testDelivery({request: db.request, pause: async () => assert.fail('unexpected pause')});
  assert.equal(db.calls.length, 0);
});
test('synthetic issue creation lost response is reconciled safely by a repeat drill', async () => {
  const db = fakeGitHub(); let count = 0;
  const input = {enabled: true, request: db.request, context,
    now: () => stamp(120 + count++ * 60), pause: async () => {}};
  db.failAfter((method, path) => method === 'POST' && path === '/issues');
  await assert.rejects(testDelivery(input)); await testDelivery(input);
  assert.equal(db.issues.length, 1); assert.equal(db.comments.get(1).length, 1);
  assert.equal(db.issues[0].state, 'closed');
});
test('new issue visibility lag is polled without a second creation', async () => {
  const db = fakeGitHub(); let lag = 2; const pauses = [];
  const request = async (method, path, body) => {
    const result = await db.request(method, path, body);
    if (method === 'GET' && path.startsWith('/issues?') && db.issues.length && lag-- > 0) return [];
    return result;
  };
  const input = {request, pause: async ms => { pauses.push(ms); }};
  await apply(db, fixture({auth: 503}), input); await apply(db, fixture({auth: 503}), input);
  assert.equal(db.issues.length, 1); assert.equal(db.writes().length, 1); assert.deepEqual(pauses, [1000, 2000]);
});
test('indefinitely invisible creation stops without retrying the write', async () => {
  const db = fakeGitHub(); const request = async (method, path, body) => {
    const result = await db.request(method, path, body);
    return method === 'GET' && path.startsWith('/issues?') ? [] : result;
  };
  await assert.rejects(apply(db, fixture({auth: 503}), {request, pause: async () => {}}), /not yet visible/);
  assert.equal(db.issues.length, 1); assert.equal(db.writes().length, 1);
});
test('a stale collection cannot repeat closure after direct issue readback', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503})); await apply(db, fixture({}, {}, 60));
  const request = async (method, path, body) => {
    const result = await db.request(method, path, body);
    return method === 'GET' && path.startsWith('/issues?') ? result.map(issue => ({...issue, state: 'open'})) : result;
  };
  const before = db.writes().length; await apply(db, fixture({}, {}, 120), {request});
  assert.equal(db.writes().length, before);
});
test('recovery comment visibility lag cannot cause repeated mentions', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503})); let lag = 2;
  const request = async (method, path, body) => {
    const result = await db.request(method, path, body);
    if (method === 'GET' && path.includes('/comments?') && db.comments.get(1)?.length && lag-- > 0) return [];
    return result;
  };
  await apply(db, fixture({}, {}, 60), {request, pause: async () => {}});
  assert.equal(db.comments.get(1).length, 1); assert.equal(db.issues[0].state, 'closed');
});
test('incomplete comment listing fails closed before duplicate recovery writes', async () => {
  const db = fakeGitHub(); await apply(db, fixture({auth: 503})); await apply(db, fixture({}, {}, 60));
  const request = async (method, path, body) => path.includes('/comments?') ? [] : db.request(method, path, body);
  const before = db.writes().length;
  await assert.rejects(apply(db, fixture({}, {}, 120), {request}), /Comment history/); assert.equal(db.writes().length, before);
});
