const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const root='security-releases/20261030-portal-followup/';
const before=JSON.parse(fs.readFileSync(root+'question-content-before.json'));
const after=JSON.parse(fs.readFileSync(root+'question-content-after.json'));
const dom=new JSDOM('<main></main>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();
Object.assign(c,{TextDecoder,esc:s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;')});
const html=fs.readFileSync('web/index.html','utf8');vm.runInContext(html.slice(html.indexOf('function ent(t)'),html.indexOf('const fmt =')),c);
test('repairs preserve answer keys and render one safe, legible figure each',()=>{
 assert.equal(after.length,4);
 for(const q of after){
  assert.deepEqual(q.correct,before.find(x=>x.id===q.id).correct);
  if(!q.assets.svg)continue;
  dom.window.document.querySelector('main').innerHTML=c.figure(q.assets);
  const svgs=dom.window.document.querySelectorAll('main svg');assert.equal(svgs.length,1);
  assert.equal(dom.window.document.querySelectorAll('main img').length,0);
  const svg=svgs[0];assert.equal(svg.getAttribute('viewBox'),q.assets.svg.match(/viewBox="([^"]+)/)[1]);
  assert.doesNotMatch(svg.outerHTML,/script|onload|foreignObject/);
  for(const t of svg.querySelectorAll('text'))assert(Number(t.getAttribute('font-size'))>=12);
  if(process.env.PORTAL_FIGURE_QA_DIR)fs.writeFileSync(require('node:path').join(process.env.PORTAL_FIGURE_QA_DIR,(q.track_id==='sat'?'snowfall':'histogram')+'-rendered.svg'),svg.outerHTML);
 }
 const snow=after.find(q=>q.track_id==='sat');assert.match(snow.assets.svg,/\(2003, 40\)/);assert.match(snow.assets.svg,/\(2007, 10\)/);assert.equal((40-10)/40*100,snow.correct[0]);
 const histogram=after.find(q=>q.assets.figure_review?.source_library_id);assert.match(histogram.assets.svg,/Approximate counts/);
 const ratio=400/200,options=histogram.choices.map(x=>{const [a,b]=x.text.split('/').map(Number);return {key:x.key,error:Math.abs(a/b-ratio)};}).sort((a,b)=>a.error-b.error);assert.equal(options[0].key,histogram.correct);
 const chips=after.find(q=>q.id==='e773194a-5f49-6be4-2600-4c9790f93f05');assert.equal(120*.9,108);assert.equal(((3/108-3.25/120)/(3.25/120)*100).toFixed(2),'2.56');assert.match(chips.choices.find(x=>x.key===chips.correct).text,/increased by about 2.56%/);
 const river=after.find(q=>q.id==='d29b13cd-c9c1-5285-2c63-6cea6a4bf68c');assert.equal(river.topic,'Linear functions and slope');assert.equal((34-26)/.5,16);
});
