// Build a browser-only comparison; never copy this output into production dist.
// node tests/build_full_exam_grid_qa.cjs OUT_DIR [LIVE_INDEX_HTML]
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const {examFixtures,extract}=require('./full_exam_grid_fixture.cjs');
const out=path.resolve(process.argv[2]),live=process.argv[3];
fs.mkdirSync(path.join(out,'dist'),{recursive:true});fs.mkdirSync(path.join(out,'.openai'),{recursive:true});
fs.writeFileSync(path.join(out,'.openai/hosting.json'),JSON.stringify({static:{directory:'dist'}}));
const sources={original:cp.execFileSync('git',['show','40a22a67be2402a9636a28184821057813b09047:web/index.html'],{encoding:'utf8'}),draft:fs.readFileSync('web/index.html','utf8')};
if(live)sources.live=fs.readFileSync(live,'utf8');
if(process.argv[4])sources['live-draft']=fs.readFileSync(process.argv[4],'utf8');
const pages={};
for(const [name,html] of Object.entries(sources)){
 let styles=[...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(x=>x[1]).join('\n');
 for(const tag of html.match(/<link\b[^>]+>/g)||[]){if(!/rel="stylesheet"/.test(tag))continue;const href=tag.match(/href="([^"]+)"/)?.[1];if(!href?.startsWith('/'))continue;const file=href.slice(1).split('?')[0];const src=name.startsWith('live')?path.join(path.dirname(live),'live-assets',file):path.join('web',file);if(fs.existsSync(src))styles+='\n'+fs.readFileSync(src,'utf8');else throw Error('Missing CSS '+src);}
 const fonts=(html.match(/<link[^>]+href="https:\/\/fonts\.googleapis\.com\/css[^>]+>/g)||[]).join('\n');
 const helpers=(html.includes('function displayTitle(')?extract(html,'function displayTitle(','function scoreClass('):'')+(html.match(/function scoreClass\([^\n]+/)?.[0]||'');
 const render=helpers+'\n'+extract(html,'function assessmentRow(','function historySection(');
 const wire=extract(html,'function wireDashboard()','/* ========================== EXAM RUNNER');
 const body=`<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${name} full exam grid fixture</title>${fonts}<style>${styles}</style></head><body class="${name.startsWith('live')?'portal-shared-ui':''}"><section id="vList" class="wrap list"><div id="examList"><div id="dashboardContent"></div></div></section><output id="qaAction" aria-live="polite" style="display:block;padding:12px">No fixture action</output><details><summary>Browser measurements</summary><pre id="qaMetrics" style="white-space:pre-wrap"></pre></details><script>
const params=new URLSearchParams(location.search),track=params.get('track')||'sat';
const ST={track:{id:track}},DASH={exams:(${examFixtures.toString()})(track,params.has('stress'))};
const $=id=>document.getElementById(id),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function startExam(id,untimed){$('qaAction').textContent='Fixture start/resume: '+id+'; untimed: '+untimed;}
function openReview(id){$('qaAction').textContent='Fixture review: '+id;}
${render}
${wire}
let samples=[];for(let i=0;i<7;i++){const start=performance.now();$('dashboardContent').innerHTML=fullExamSection();wireDashboard();$('dashboardContent').getBoundingClientRect();samples.push(performance.now()-start);}
async function measure(){await document.fonts.ready;requestAnimationFrame(()=>{
 const cards=[...document.querySelectorAll('.full-exam-grid>.exam-pair,.full-exam-grid>.exam-row')];
 const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}};
 const buttons=[...document.querySelectorAll('.full-exam-grid button')];
 const broken=[];for(const card of cards){const r=card.getBoundingClientRect();for(const child of card.querySelectorAll('h2,h3,.meta,.badge,button')){const c=child.getBoundingClientRect();if(c.left<r.left-1||c.right>r.right+1||c.bottom>r.bottom+1)broken.push({card:card.querySelector('h2,h3').textContent,element:child.textContent,rect:rect(child),cardRect:rect(card)});}}
 const result={version:'${name}',track,viewport:innerWidth,documentWidth:document.documentElement.scrollWidth,overflow:document.documentElement.scrollWidth>innerWidth,cardCount:cards.length,grids:[...document.querySelectorAll('.full-exam-grid')].map(g=>({columns:getComputedStyle(g).gridTemplateColumns,rect:rect(g)})),cards:cards.map(c=>({title:c.querySelector('h2,h3').textContent,...rect(c)})),broken,smallTargets:buttons.filter(b=>b.getBoundingClientRect().width<44||b.getBoundingClientRect().height<44).map(b=>({label:b.textContent,...rect(b)})),moduleRows:[...document.querySelectorAll('.module-row')].slice(0,4).map(r=>({title:r.textContent,display:getComputedStyle(r).display,...rect(r)})),renderMs:samples,fonts:[...document.fonts].filter(f=>f.status==='loaded').map(f=>f.family),bodyFont:getComputedStyle(document.body).fontFamily};
 $('qaMetrics').textContent=JSON.stringify(result);parent.postMessage({kind:'qa',result},parent.location.origin);
 });}measure();
</script></body></html>`;
 pages[name]=body;fs.writeFileSync(path.join(out,'dist',name+'.html'),body);
}
fs.writeFileSync(path.join(out,'dist','index.html'),`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Full exam grid browser review</title><style>body{font:16px system-ui;margin:20px;color:#14243e}label{display:inline-flex;gap:8px;margin:8px}button,select{font:inherit;min-height:44px;padding:8px}iframe{border:1px solid #999;height:1000px;display:block}pre{white-space:pre-wrap;font-size:13px}h1{font-size:24px}.viewport{overflow:auto}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:8px}</style><h1>Full exam grid · draft browser review</h1><p>Real Chromium layout with synthetic exams and intercepted actions. No student accounts or production writes. Frame widths are CSS layout viewports, not physical devices.</p><label>Version <select id="version">${Object.keys(sources).map(k=>'<option>'+k+'</option>').join('')}</select></label><label>Width <select id="width">${[360,390,768,1280].map(w=>'<option>'+w+'</option>').join('')}</select></label><label>Course <select id="track"><option>sat</option><option>est</option><option>est2</option><option>act2</option></select></label><label><input id="stress" type="checkbox">300 extra SAT pairs</label><button id="matrix">Run layout matrix</button><p id="status" aria-live="polite">Ready</p><div class="viewport"><iframe id="frame" title="Full exam grid"></iframe></div><h2>Measurements</h2><pre id="result"></pre><h2>Matrix results</h2><pre id="results"></pre><script>
const versions=${JSON.stringify(Object.keys(sources))},pages=${JSON.stringify(pages).replace(/<\//g,'<\\/')},frame=document.getElementById('frame'),results=[];
function show(){frame.style.width=width.value+'px';frame.srcdoc=pages[version.value].replace('new URLSearchParams(location.search)','new URLSearchParams('+JSON.stringify('track='+track.value+(stress.checked?'&stress=1':''))+')');}
for(const id of ['version','width','track','stress'])document.getElementById(id).onchange=show;
let accept;addEventListener('message',e=>{if(e.origin!==location.origin||e.data.kind!=='qa')return;result.textContent=JSON.stringify(e.data.result,null,2);if(accept){accept(e.data.result);accept=null}});
matrix.onclick=async()=>{matrix.disabled=true;results.length=0;for(const v of versions)for(const t of ['sat','est','est2','act2'])for(const w of [360,390,768,1280]){version.value=v;track.value=t;width.value=w;stress.checked=false;document.getElementById('status').textContent=v+' '+t+' '+w;const next=new Promise(r=>accept=r);show();results.push(await next);document.getElementById('results').textContent=JSON.stringify(results)}matrix.disabled=false;document.getElementById('status').textContent='Complete: '+results.length+' layouts'};show();
</script></html>`);
console.log('QA preview written to '+out);
