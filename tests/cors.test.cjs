const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { stripTypeScriptTypes } = require('node:module');

async function helpers() {
  const source = readFileSync(require('node:path').join(__dirname, '../supabase/functions/_shared/http.ts'), 'utf8')
    .replace(/^import .*from .*;$/m, '')
    .replaceAll('Deno.env.get', '(() => undefined)');
  return import('data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(source)).toString('base64'));
}

test('CORS permits both portal domains for preflight, success and errors', async () => {
  const { serve, json, ApiError } = await helpers();
  for (const origin of ['https://math.portal.ghoneem.com', 'https://ghoneem-exam-portal.xxx64220.chatgpt.site']) {
    for (const method of ['OPTIONS', 'GET']) {
      const response = await serve(async () => json({ ok: true }))(new Request('https://example.test', { method, headers: { Origin: origin } }));
      assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin);
      assert.equal(response.status, 200);
      assert.match(response.headers.get('Vary'), /Origin/);
    }
    const response = await serve(async () => { throw new ApiError('missing_token', 401); })(new Request('https://example.test', { headers: { Origin: origin } }));
    assert.equal(response.status, 401);
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin);
  }
});

test('CORS does not permit unknown or lookalike origins', async () => {
  const { serve, json } = await helpers();
  for (const origin of ['https://example.com', 'https://math.portal.ghoneem.com.evil.test', 'null']) {
    const response = await serve(async () => json({ ok: true }))(new Request('https://example.test', { method: 'OPTIONS', headers: { Origin: origin } }));
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);
  }
});

test('concurrent requests keep their own CORS origin', async () => {
  const { serve, json } = await helpers();
  const origins = ['https://math.portal.ghoneem.com', 'https://ghoneem-exam-portal.xxx64220.chatgpt.site'];
  const handler = serve(async () => { await new Promise(resolve => setTimeout(resolve, 5)); return json({ ok: true }); });
  const responses = await Promise.all(origins.map(origin => handler(new Request('https://example.test', { headers: { Origin: origin } }))));
  responses.forEach((response, i) => assert.equal(response.headers.get('Access-Control-Allow-Origin'), origins[i]));
});
