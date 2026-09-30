const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const {JSDOM}=require(process.env.JSDOM_MODULE||'./passage-runtime/node_modules/jsdom');
const html=fs.readFileSync('web/index.html','utf8'),css=fs.readFileSync('web/portal-controls.css','utf8');
const dom=new JSDOM('<!doctype html><html><head></head><body></body></html>');
const c={DOMParser:dom.window.DOMParser,document:dom.window.document,esc:s=>String(s??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;')};
vm.createContext(c);
vm.runInContext(html.slice(html.indexOf('function ent(t)'),html.indexOf('const fmt =',html.indexOf('function ent(t)'))),c);
const rows=JSON.parse(fs.readFileSync(process.argv[2]||'tests/english_passage_samples.json'));
for(const row of rows){
 const original=new dom.window.DOMParser().parseFromString(row.html,'text/html');
 const output=new dom.window.DOMParser().parseFromString(c.figure({html:row.html,passage_title:row.title}),'text/html');
 assert.equal(output.body.textContent,original.body.textContent,'Passage words and question references must be retained: '+row.id);
 for(const tag of ['p','u','mark','figure','figcaption','img'])assert.equal(output.querySelectorAll(tag).length,original.querySelectorAll(tag).length,tag+' retained: '+row.id);
 const panel=output.querySelector('.english-passage');assert.ok(panel);assert.equal(panel.lang,'en');assert.equal(panel.dir,'ltr');assert.equal(panel.getAttribute('aria-label'),row.title);
 assert.equal(output.querySelectorAll('[style],[onclick],[onerror]').length,0);
}
const safe=c.cleanMarkup('<p>before <u>referenced words</u> <mark>[14]</mark> after</p><script>alert(1)</script><iframe src="https://bad.test"></iframe><figure><img src="javascript:alert(1)" onerror="bad()" alt="illustration"><img src="data:image/svg+xml;base64,AA==" onload="bad()"><figcaption>caption</figcaption></figure><a href="javascript:bad()">bad</a>');
assert.match(safe,/<u>referenced words<\/u>/);assert.match(safe,/<mark>\[14\]<\/mark>/);assert.doesNotMatch(safe,/script|iframe|javascript|svg\+xml|onerror|onload|href/);
assert.match(c.cleanMarkup('<img src="https://example.test/a.png" alt="A &amp; B">'),/src="https:\/\/example.test\/a.png"/);
assert.match(c.cleanMarkup('<img src="data:image/png;base64,aGVsbG8=">'),/data:image\/png/);
assert.match(c.figure({html:'<table><tr><td>Math table</td></tr></table>'}),/fig fig-table/);
assert.doesNotMatch(c.figure({html:'<table><tr><td>Math table</td></tr></table>'}),/english-passage/);
assert.doesNotMatch(c.figure({html:'<p>text</p>',passage_title:'"><script>bad()</script>'}),/<script>/);
assert.match(css,/max-width:72ch/);assert.match(css,/font-size:1\.125rem/);assert.match(css,/line-height:1\.85/);assert.match(css,/\.english-passage img\{[^}]*max-width:100%;height:auto/);
if(fs.existsSync('dist/index.html'))assert.equal(fs.readFileSync('dist/index.html','utf8'),html);
if(fs.existsSync('dist/portal-controls.css'))assert.equal(fs.readFileSync('dist/portal-controls.css','utf8'),css);
console.log('PASS: '+rows.length+' English passages preserve every word, paragraph, underline, reference and illustration; unsafe markup rejected; math tables unchanged; source/output synchronized.');

