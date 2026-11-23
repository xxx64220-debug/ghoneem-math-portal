// Public GETs only. Does not sign in, start attempts, deploy or alter production.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(process.argv[2]),origin='https://math.portal.ghoneem.com';
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');
const expected=fs.readFileSync(path.join(root,'index.html'),'utf8');
assert.equal(sha(expected),'565f14709952145f7bb70ed1ef5bccfa1442d64b247e5a20d9a311596657b7eb','reviewed baseline mismatch');
const section=(html,start,end)=>{const a=html.indexOf(start),b=html.indexOf(end,a);assert(a>=0&&b>a,'missing boundary '+start);return html.slice(a,b);};
const styles=html=>[...html.matchAll(/<link\b[^>]*rel=["']stylesheet["'][^>]*>/gi)].map(m=>m[0].match(/href=["']([^"']+)/)?.[1]).filter(x=>x?.startsWith('/')&&!x.startsWith('//'));
async function get(url){const start=performance.now(),r=await fetch(url,{signal:AbortSignal.timeout(20000),headers:{'Cache-Control':'no-cache'}});assert.equal(r.status,200,url);assert.equal(new URL(r.url).origin,origin);return {body:await r.text(),elapsedMs:Math.round(performance.now()-start),url:r.url};}
(async()=>{
 const live=await get(origin+'/');
 const pairs=[
  ['assessmentRow','function assessmentRow(','\nlet VOCABULARY='],
  ['fullExamSection','function fullExamSection(){','function historySection(']
 ];
 const renderers=pairs.map(([name,start,end])=>{const before=section(expected,start,end),after=section(live.body,start,end);return {name,same:before===after,expectedSha256:sha(before),currentSha256:sha(after)};});
 const cssResults=await Promise.all(styles(live.body).map(async href=>{
  const u=new URL(href.replaceAll('&amp;','&'),origin),current=await get(u.href),local=path.join(root,'live-assets',u.pathname.slice(1));
  const exists=fs.existsSync(local),result={path:u.pathname,sha256:sha(current.body),sameAsReviewed:exists?sha(fs.readFileSync(local))===sha(current.body):null};
  if(!exists||!result.sameAsReviewed)result.changedCssExcerpt=current.body.slice(-1200);
  return result;
 }));
 const fixes={
  mobileFlexBasis:live.body.includes('.full-exam-grid>.exam-row>.exam-tile-copy{flex-basis:auto!important}'),
  sortedUnpairedModules:live.body.includes('singles.sort(compareExams);'),
  naturalComparator:live.body.includes("new Intl.Collator(undefined,{numeric:true,sensitivity:'base'})"),
  pendingCombinedGrade:live.body.includes(":s1.done&&s2.done?'Awaiting grading':"),
  fullReviewAccessibleName:live.body.includes("aria-label=\""+'\${esc(\'Review full exam: \'+title)}'+"\"")
 };
 const report={checkedAt:new Date().toISOString(),origin,htmlSha256:sha(live.body),htmlBytes:Buffer.byteLength(live.body),publicFetchMs:live.elapsedMs,baselineHtmlSha256:sha(expected),renderers,fixes,styles:cssResults,allReviewedStylesStillLinked:styles(expected).every(h=>cssResults.some(r=>r.path===new URL(h.replaceAll('&amp;','&'),origin).pathname)),limits:['Static public-source audit; not a browser rendering or authenticated workflow test.','One fetch timing includes GitHub runner/network overhead; not a production latency benchmark.']};
 fs.writeFileSync(path.join(root,'audit-current.json'),JSON.stringify(report,null,2)+'\n');
 console.log('DEPLOYED_GRID_AUDIT '+JSON.stringify(report));
 assert(report.allReviewedStylesStillLinked,'A reviewed stylesheet is no longer linked');
 if(!renderers.every(r=>r.same)||!Object.values(fixes).every(Boolean))console.log('::warning::Current deployment differs from the reviewed grid; an isolated draft overlay will be verified.');
 const original=fs.readFileSync(path.join(root,'live-index.html'),'utf8');
 let candidate=live.body;
 for(const [name,start,end] of pairs){
  const current=section(live.body,start,end),before=section(original,start,end),after=section(expected,start,end);
  if(current!==before&&current!==after){
   console.log('UNREVIEWED_RENDERER '+JSON.stringify({name,current,baseline:before}));
   throw Error('Renderer changed beyond the reviewed fixes: '+name);
  }
  candidate=candidate.replace(current,after);
 }
 const rule='.full-exam-grid>.exam-row>.exam-tile-copy{flex-basis:auto!important}';
 if(!candidate.includes(rule)){
  assert.equal((candidate.match(/<\/head>/g)||[]).length,1);
  candidate=candidate.replace('</head>','<style id="full-exam-tile-sizing">/* Keep column tiles clear of the legacy mobile row basis. */\n'+rule+'</style>\n</head>');
 }
 const runner='function wireDashboard()';
 assert.equal(candidate.slice(candidate.indexOf(runner)),live.body.slice(live.body.indexOf(runner)),'Newer deployed handlers and runner changed');
 fs.writeFileSync(path.join(root,'audit-live-index.html'),live.body);
 fs.writeFileSync(path.join(root,'audit-draft-index.html'),candidate);
 let patch='';
 try{patch=require('node:child_process').execFileSync('diff',['-u','--label','a/index.html','--label','b/index.html',path.join(root,'audit-live-index.html'),path.join(root,'audit-draft-index.html')],{encoding:'utf8'});}
 catch(e){if(e.status!==1)throw e;patch=e.stdout;}
 fs.writeFileSync(path.join(root,'audit-current-grid.patch'),patch);
 console.log('DRAFT_GRID_OVERLAY '+JSON.stringify({baselineSha256:sha(live.body),candidateSha256:sha(candidate),handlersAndRunnerUnchanged:true,patch}));

})().catch(e=>{console.error(e);process.exitCode=1;});
