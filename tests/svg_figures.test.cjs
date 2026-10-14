const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const dom=new JSDOM('<main></main>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();
Object.assign(c,{TextDecoder,esc:s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;')});
const html=fs.readFileSync('web/index.html','utf8');vm.runInContext(html.slice(html.indexOf('function ent(t)'),html.indexOf('const fmt =')),c);
const uri=s=>'data:image/svg+xml;base64,'+Buffer.from(s).toString('base64');
test('all 16 actual SVG figure attachments render without changing their source',()=>{
 for(const a of JSON.parse(fs.readFileSync('tests/fixtures/svg-figures.json'))){
  const source=Buffer.from(a.figure.split(',')[1],'base64').toString('utf8'),out=c.figure({figure:a.figure});
  const expected=new dom.window.DOMParser().parseFromString(c.cleanMarkup(source),'text/html');
  dom.window.document.querySelector('main').innerHTML=out;
  assert.equal(dom.window.document.querySelectorAll('main svg').length,1,a.id);
  assert.equal(dom.window.document.querySelector('main svg').textContent,expected.querySelector('svg').textContent,a.id);
 }
});
test('SVG uses the existing allowlist, preserves UTF-8 labels and fails closed',()=>{
 const src='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 80" onload="alert(1)"><text x="2" y="20">θ = 60°</text><script>alert(1)</script><foreignObject><p>unsafe</p></foreignObject><a href="javascript:alert(1)"><text>link</text></a><path d="M1 1L20 20" fill="url(https://unsafe.invalid)" onclick="alert(1)"/></svg>';
 const out=c.figure({figure:uri(src)});assert.match(out,/θ = 60°/);assert.doesNotMatch(out,/script|foreignObject|onload|onclick|href|javascript:|url\(/i);
 assert.equal(c.figure({figure:uri('<svg><unclosed>')}),'');
 assert.equal(c.figure({figure:uri('<div>not svg</div>')}),'');
 assert.equal(c.figure({figure:'data:image/svg+xml;base64,%%%'}),'');
 assert.equal(c.figure({figure:uri('<svg/>'),html:'<table><tr><td>42</td></tr></table>'}).includes('<td>42</td>'),true);
});
