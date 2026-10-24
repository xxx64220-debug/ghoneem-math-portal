const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {JSDOM} = require('./english-runtime/node_modules/jsdom');
const katex = require('./english-runtime/node_modules/katex');
const {containsSecret, checkPublic} = require('../scripts/security-public.cjs');
const read = p => fs.readFileSync(p, 'utf8');
const student = read('web/index.html'), admin = read('web/admin.html');
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

function renderer(source) {
  const dom = new JSDOM('<main></main>', {runScripts:'outside-only'});
  const c = dom.getInternalVMContext();
  Object.assign(c, {esc, TextDecoder});
  vm.runInContext(source.slice(source.indexOf('function ent(t)'), source.indexOf('const fmt =')), c);
  return c;
}
function assertInert(doc) {
  assert.equal(doc.querySelector('script,iframe,object,embed,form,base,link,style,foreignObject,animate,set'), null);
  for (const el of doc.querySelectorAll('*')) for (const a of el.attributes) {
    assert.doesNotMatch(a.name, /^on|^srcdoc$/i);
    assert.doesNotMatch(a.value, /javascript:|vbscript:|url\s*\(/i);
  }
}
for (const [name, source] of [['student', student], ['instructor', read('web/instructor-practice.js')]]) {
  test(`${name}: hostile bank HTML/SVG stays inert after DOM insertion`, () => {
    const c = renderer(source);
    const attacks = [
      '<img src="x" onerror="alert(1)"><script>alert(1)</script><p>Keep this text</p>',
      '<svg onload="alert(1)"><foreignObject><img src=x onerror=alert(1)></foreignObject><a href="javascript:alert(1)"><text>bad link</text></a><path d="M0 0L2 2" fill="url(https://evil.invalid)"/></svg>',
      '<math><mtext><table><mglyph><style><!--</style><img title="--><img src=x onerror=alert(1)>">',
      '<svg><animate attributeName="href" values="javascript:alert(1)"/><set attributeName="onload" to="alert(1)"/><text onclick="alert(1)">θ</text></svg>',
      '<iframe srcdoc="<script>alert(1)</script>"></iframe><form action="https://evil.invalid"><input name=password></form><base href="https://evil.invalid">',
    ];
    for (const html of attacks) {
      c.document.querySelector('main').innerHTML = c.figure({html, svg:html});
      assertInert(c.document.querySelector('main'));
    }
    c.document.querySelector('main').innerHTML = c.figure({figspec:{lines:[['0" onload="alert(1)',0,10,10]],extra:attacks[0]}});
    assertInert(c.document.querySelector('main'));
    c.document.querySelector('main').innerHTML = c.figure({figure:'https://example.test/a.png" onerror="alert(1)',figure_caption:'" onload="alert(1)'});
    for (const a of c.document.querySelector('img').attributes) assert.doesNotMatch(a.name, /^on/i);
  });
}

test('KaTeX rejects malicious links, HTML attributes and inherited trust', () => {
  const expressions = ['\\href{javascript:alert(1)}{x}', '\\includegraphics{https://evil.invalid/a.png}', '\\htmlData{onmouseover=alert(1)}{x}'];
  // Matches the published prototype-pollution advisory without modifying global prototypes.
  for (const expression of expressions) {
    const options = Object.create({trust:true}); options.throwOnError = false;
    const doc = new JSDOM(katex.renderToString(expression, options)).window.document;
    assert.equal(doc.querySelector('a,img,[onmouseover],[onerror]'), null);
  }
  const doc = new JSDOM(katex.renderToString('\\frac{1}{2}+x^{2}=\\sqrt{9}', {trust:false,throwOnError:true})).window.document;
  assert(doc.querySelector('.katex'));
  assert.equal(doc.querySelector('.katex-error'), null);
});

test('student math adapter sets explicit trust and expansion limits', () => {
  let options;
  const dom = new JSDOM('<main></main>', {runScripts:'outside-only'}), c = dom.getInternalVMContext();
  c.renderMathInElement=(_el,opts)=>{options=opts;};
  vm.runInContext(read('web/portal-math.js'),c);
  vm.runInContext(student.slice(student.indexOf('function math(el)'), student.indexOf('const FRIENDLY')), c);
  c.math(c.document.querySelector('main'));
  assert.equal(options.trust,false); assert.equal(options.maxExpand,1000); assert.equal(options.maxSize,20);
});

test('CSV downloads neutralize formula/control prefixes and escape headings', async () => {
  const dom = new JSDOM('<body></body>', {runScripts:'outside-only'}), c = dom.getInternalVMContext();
  let blob;
  Object.assign(c, {Blob, URL:{createObjectURL(value){blob=value;return 'blob:test';},revokeObjectURL(){}},setTimeout(){}});
  dom.window.HTMLAnchorElement.prototype.click = function(){};
  vm.runInContext(admin.slice(admin.indexOf('function csv(rows, name)'),admin.indexOf('function questionPdf(')), c);
  for (const attack of ['=1+1','+SUM(1,2)','-1+2','@SUM(1,2)',' \t=1+1','\r=1+1','\n@SUM(1,2)','\ufeff=1+1','\u0000=1+1','\tplain']) {
    c.csv([{value:attack}], 'security-test');
    assert.equal(new TextDecoder('utf-8',{ignoreBOM:true}).decode(await blob.arrayBuffer()), '\ufeff"value"\r\n"\''+attack.replaceAll('"','""')+'"');
  }
  c.csv([{'=heading':'ordinary, "quoted" text',number:-12}], 'security-test');
  assert.equal(new TextDecoder('utf-8',{ignoreBOM:true}).decode(await blob.arrayBuffer()), '\ufeff"\'=heading","number"\r\n"ordinary, ""quoted"" text","-12"');
});

test('public pages pin audited packages and validate CDN bytes with SRI', () => {
  const versions = {...JSON.parse(read('tests/english-runtime/package.json')).dependencies,...JSON.parse(read('tests/security-runtime/package.json')).dependencies};
  assert(read('supabase/functions/_shared/http.ts').includes('@supabase/supabase-js@'+versions['@supabase/supabase-js']+'"'));
  for (const html of [student,admin]) {
    const doc = new JSDOM(html).window.document;
    for (const el of doc.querySelectorAll('script[src^="https://"],link[href^="https://cdn.jsdelivr.net/"]')) {
      const url = el.src || el.href;
      const match = url.match(/^https:\/\/cdn\.jsdelivr\.net\/npm\/(katex|@supabase\/supabase-js)@([^/]+)\/(.+)$/);
      assert(match, `Unreviewed executable CDN: ${url}`);
      const [,pkg,version,file] = match;
      assert.equal(version,versions[pkg]);
      const base = pkg === 'katex' ? 'tests/english-runtime' : 'tests/security-runtime';
      const expected = 'sha384-'+crypto.createHash('sha384').update(fs.readFileSync(`${base}/node_modules/${pkg}/${file}`)).digest('base64');
      assert.equal(el.integrity || el.getAttribute('integrity'),expected);
      assert.equal(el.getAttribute('crossorigin'),'anonymous');
    }
    assert.equal(doc.querySelector('meta[name="referrer"]').content,'no-referrer');
    const csp = doc.querySelector('meta[http-equiv="Content-Security-Policy"]').content;
    assert.match(csp,/base-uri 'none'/);assert.match(csp,/object-src 'none'/);assert.match(csp,/form-action 'self'/);
    // Meta CSP cannot enforce frame-ancestors: never claim clickjacking protection here.
    assert.doesNotMatch(csp,/frame-ancestors/);
  }
});

test('credential scanner detects private keys and service JWTs without rejecting publishable keys', () => {
  const jwt = ['eyJhbGciOiJIUzI1NiJ9',Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url'),'signature'].join('.');
  assert(containsSecret(jwt));
  assert(containsSecret('sb_'+'secret_'+'a'.repeat(20)));
  assert(containsSecret('-----BEGIN '+'PRIVATE KEY-----'));
  assert(!containsSecret('sb_'+'publishable_'+'a'.repeat(20)));
  assert(!containsSecret('SUPABASE_SERVICE_ROLE_KEY'));
  assert(checkPublic('web') > 0);
});

