const {test,expect}=require('@playwright/test');
const rows=require('../../content-releases/20261005_reviewed_exam_versions/adaptations.json');
test('every corrected question and eight diagrams render across exam and practice surfaces',async({page,context},testInfo)=>{
 test.setTimeout(90000);const errors=[],blocked=[];page.on('pageerror',e=>errors.push(e.message));
 const sdk=`window.supabase={createClient(){const session={access_token:'synthetic-local-only',user:{id:'test-student'}};return {auth:{onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),getSession:async()=>({data:{session}})},from:()=>({upsert:async()=>({error:null})})}}};`;
 await context.route('**/*',async route=>{
  const url=new URL(route.request().url());if(url.origin==='http://127.0.0.1:4173')return route.continue();
  if(url.hostname==='cdn.jsdelivr.net'&&url.pathname.includes('supabase-js'))return route.fulfill({contentType:'application/javascript',body:sdk});
  if(url.hostname==='fonts.googleapis.com'||url.hostname==='cdn.jsdelivr.net')return route.fulfill({body:'',contentType:route.request().resourceType()==='script'?'application/javascript':'text/css'});
  if(url.hostname==='wfhurjyouemahvkcfkdz.supabase.co'&&url.pathname.startsWith('/functions/v1/')){
   const name=url.pathname.split('/').pop();let data;
   if(name==='me-tracks')data=url.search?{exams:[],dashboard:{}}:{role:'student',tracks:[{id:'est2',name:'EST II Math',exams_available:0,attempts_done:0},{id:'sat',name:'SAT Math',exams_available:0,attempts_done:0}]};
   else if(name==='portal-controls')data={revision_visible:true};
   else if(name==='daily-challenge')data={date:'2026-10-05',quiz:[],checklist:{},leaderboard:[]};
   else{blocked.push(url.href);return route.abort();}return route.fulfill({json:data});
  }
  blocked.push(url.href);return route.abort();
 });
 await page.goto('/');await expect(page.locator('#vTracks')).toBeVisible();await page.getByRole('button',{name:/EST II Math/}).click();
 for(const q of rows){
  await page.evaluate(q=>{ST.run={exam:{track_id:q.track_id},questions:[q]};ST.idx=0;ST.flags=new Set();renderQ();show('vRun');},q);
  await expect(page.locator('#qcard .choice')).toHaveCount(q.choices.length);
  await expect(page.locator('#qcard .stem')).toContainText(q.stem);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize().width+1);
  if(q.assets.svg){
   const svg=page.locator('#qcard svg');await expect(svg).toBeVisible();await expect(svg).toHaveAttribute('aria-label',/.+/);
   expect(await svg.locator('text').count()).toBeGreaterThan(3);
   await page.locator('#qcard').screenshot({path:testInfo.outputPath(q.code+'.png')});
  }
  // The same renderer is used in all four practice surfaces. No key leaks into a question.
  for(const surface of ['daily','drill','notebook','revision']){
   await page.evaluate(({q,surface})=>{
    let out;
    if(surface==='daily'){DASH.daily={track:q.track_id,quiz:[q],checklist:{},leaderboard:[],completed:false};out=dailyPanel();}
    if(surface==='drill'){DASH.drill={drill_id:'fixture',topics:[q.topic],completed:false,questions:[q]};out=drillPanel();}
    if(surface==='notebook'){DASH.mistakes={remaining:1,mastered:0,items:[{...q,streak:0}]};out=mistakesPanel();}
    if(surface==='revision'){REV.session={id:'fixture',questions:[q],completed:false};out=revisionSessionPanel();}
    document.getElementById('dashboardContent').innerHTML=out;show('vList');
   },{q:{...q,correct:undefined,explanation:undefined},surface});
   if(q.assets.svg)await expect(page.locator('#dashboardContent svg')).toBeVisible();
   expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize().width+1);
  }
 }
 expect(errors).toEqual([]);expect(blocked).toEqual([]);
});
