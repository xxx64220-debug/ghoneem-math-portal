// Generate a local-only browser audit. The app HTML/CSS/JS is copied unchanged,
// apart from local CDN URLs, a synthetic SDK boundary and test-only scripts.
// Never place this directory in portal-static or publish it.
const fs=require('node:fs'),path=require('node:path');
const {cases,fixtureSDK,fixtureFetch}=require('./math-rendering-fixtures.cjs');
const root=path.resolve(__dirname,'../..'),previewRoot=path.resolve(process.argv[2]||path.join(root,'../math-audit-preview')),dest=path.join(previewRoot,'dist');
fs.mkdirSync(dest,{recursive:true});
fs.cpSync(path.join(root,'web'),dest,{recursive:true});
fs.cpSync(path.join(root,'tests/english-runtime/node_modules/katex/dist'),path.join(dest,'katex'),{recursive:true});
fs.writeFileSync(path.join(dest,'fixture-sdk.js'),`(${fixtureSDK})();\n(${fixtureFetch})(${JSON.stringify(cases)});window.mathAuditCases=${JSON.stringify(cases)};`);
fs.copyFileSync(path.join(__dirname,'math-layout-checks.js'),path.join(dest,'math-layout-checks.js'));
let html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
html=html.replace('; upgrade-insecure-requests','').replace(/https:\/\/cdn.jsdelivr.net\/npm\/katex@0.18.2\/dist\//g,'/katex/')
 .replace(/https:\/\/cdn.jsdelivr.net\/npm\/@supabase\/supabase-js@2.50.0\/dist\/umd\/supabase.js/g,'/fixture-sdk.js')
 .replace(/<script defer src="\/portal-install.js"><\/script>/,'')
 .replace(/<script defer src="\/portal-notifications.js"><\/script>/,'')
 .replace(/ integrity="[^"]+"/g,'').replace(/ crossorigin="anonymous"/g,'')
 .replace('</body>','<script src="/math-layout-checks.js"></script></body>');
const revision=require('node:crypto').createHash('sha256').update(html).update(fs.readFileSync(path.join(__dirname,'math-layout-checks.js'))).update(fs.readFileSync(path.join(root,'web/portal-math-layout.css'))).digest('hex').slice(0,12);
html=html.replace(/(src|href)="(\/[^"]+)"/g,(_,attr,url)=>attr+'="'+url+(url.includes('?')?'&':'?')+'audit='+revision+'"');
fs.writeFileSync(path.join(dest,'exam.html'),html);
fs.mkdirSync(path.join(previewRoot,'.openai'),{recursive:true});fs.writeFileSync(path.join(previewRoot,'.openai/hosting.json'),JSON.stringify({static:{directory:'dist'}}));
fs.writeFileSync(path.join(dest,'index.html'),`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>Math layout audit — isolated exam fixtures</title><style>body{font:16px system-ui;margin:16px;background:#edf0f5}label,button{margin-right:12px}button,select{padding:9px}iframe{display:block;border:1px solid #94a3b8;margin-top:16px;height:1180px;background:white}pre{white-space:pre-wrap;max-height:300px;overflow:auto}.fail{color:#a11}</style><h1>Mathematical rendering audit</h1><p>Actual student exam and review renderer · synthetic session · no production requests · real KaTeX 0.18.2 with local fonts.</p><label>Width <select id="width">${[1280,820,390,320].map(w=>'<option>'+w+'</option>').join('')}</select></label><label>Track <select id="track"><option value="sat">SAT</option><option value="est">EST I</option><option value="est2">EST II</option></select></label><label>Question <select id="question">${cases.map((q,i)=>'<option value="'+i+'">'+q.id+'</option>').join('')}</select></label><label>Surface <select id="surface"><option>exam</option><option>review</option></select></label><button id="show">Show question</button><button id="run">Run all viewport checks</button><pre id="results">Ready</pre><pre id="rawResults" hidden></pre><iframe sandbox="allow-scripts allow-same-origin" title="Actual exam viewport" id="exam" width="1280" src="/exam.html?audit=${revision}&track=sat"></iframe><script>
const frame=document.getElementById('exam'),out=document.getElementById('results'),w=document.getElementById('width'),t=document.getElementById('track'),q=document.getElementById('question'),s=document.getElementById('surface');
const tick=()=>new Promise(resolve=>setTimeout(resolve,40));
async function load(width,track){frame.width=width;if(frame.dataset.track!==track){frame.src='/exam.html?audit=${revision}&track='+track;frame.dataset.track=track;await new Promise(resolve=>frame.onload=resolve);}for(let i=0;i<300&&!frame.contentWindow.mathAuditReady;i++)await tick();if(!frame.contentWindow.mathAuditReady)throw Error('Fixture did not start');}
document.getElementById('show').onclick=async()=>{await load(+w.value,t.value);await frame.contentWindow.mathLayoutChecks.preview(+q.value,s.value);out.textContent='Showing '+t.value+' / '+w.value+'px / '+q.selectedOptions[0].textContent+' / '+s.value;};
document.getElementById('run').onclick=async()=>{try{const rows=[];for(const width of [1280,820,390,320])for(const track of ['sat','est','est2']){out.textContent='Checking '+width+'px / '+track;await load(width,track);rows.push(...await frame.contentWindow.mathLayoutChecks.run());}window.auditResults=rows;document.getElementById('rawResults').textContent=JSON.stringify(rows,null,2);const failures=rows.filter(r=>r.issues.length);out.textContent=JSON.stringify({checks:rows.length,failures:failures.length,fonts:frame.contentWindow.mathAuditFontStatus,details:failures},null,2);out.className=failures.length?'fail':'';}catch(e){out.textContent=e.stack;}};
</script>`);
console.log(dest);
