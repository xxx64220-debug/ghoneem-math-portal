const {test,expect}=require('@playwright/test');
test('under-review cards preserve history; SVG graphs render safely in every practice surface',async({page,context})=>{
 const errors=[],blocked=[];page.on('pageerror',e=>errors.push(e.message));
 const sdk=`window.supabase={createClient(){const session={access_token:'synthetic-local-only',user:{id:'test-student'}};return {auth:{onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),getSession:async()=>({data:{session}})},from:()=>({upsert:async()=>({error:null})})}}};`;
 await context.route('**/*',async route=>{
  const url=new URL(route.request().url());if(url.origin==='http://127.0.0.1:4173')return route.continue();
  if(url.href==='https://math.portal.ghoneem.com/assets/question-figures/elite-m2-q21-20261004.png')return route.fulfill({path:require('node:path').join(__dirname,'../../web/assets/question-figures/elite-m2-q21-20261004.png'),contentType:'image/png'});
  if(url.hostname==='cdn.jsdelivr.net'&&url.pathname.includes('supabase-js'))return route.fulfill({contentType:'application/javascript',body:sdk});
  if(url.hostname==='fonts.googleapis.com'||url.hostname==='cdn.jsdelivr.net')return route.fulfill({body:'',contentType:route.request().resourceType()==='script'?'application/javascript':'text/css'});
  if(url.hostname==='wfhurjyouemahvkcfkdz.supabase.co'&&url.pathname.startsWith('/functions/v1/')){
   const name=url.pathname.split('/').pop();let data;
   if(name==='me-tracks')data=url.search?{exams:[],dashboard:{}}:{role:'student',tracks:[{id:'sat',name:'SAT Math',exams_available:0,attempts_done:0},{id:'est',name:'EST I Math',exams_available:0,attempts_done:0}]};
   else if(name==='portal-controls')data={revision_visible:true};
   else if(name==='daily-challenge')data={date:'2026-10-04',quiz:[],checklist:{},leaderboard:[]};
   else {blocked.push(url.href);return route.abort();}return route.fulfill({json:data});
  }
  blocked.push(url.href);return route.abort();
 });
 await page.goto('/');await expect(page.locator('#vTracks')).toBeVisible();await page.getByRole('button',{name:/SAT Math/}).click();await expect(page.locator('#dashboardContent')).toBeVisible();
 const fixture=await page.evaluate(()=>{
  const svg='data:image/svg+xml;base64,'+btoa('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 250 160" onload="window.__bad=true"><path d="M20 130L210 20" stroke="blue"/><text x="30" y="150">Source graph</text><script>window.__bad=true</script></svg>');
  const q={id:'synthetic-svg',stem:'Which model fits?',type:'mcq',topic:'Functions',choices:['A','B','C','D'].map(key=>({key,text:key})),assets:{figure:svg}};
  const held={id:'held-exam',title:'Exam awaiting review',assessment_type:'lesson_exam',content_ready:false,open:false,questions:5,duration_seconds:600};
  const history={...held,last:{id:'historical-attempt',status:'graded',score:4,total:5},retake_available:true};
  DASH.exams=[held,history];setDashboardView('lesson_exam');return q;
 });
 await expect(page.locator('[data-start="held-exam"]')).toBeDisabled();await expect(page.locator('[data-review="historical-attempt"]')).toBeEnabled();await expect(page.locator('[data-start="held-exam"]')).toHaveCount(1);
 await page.evaluate(q=>{DASH.mistakes={remaining:1,mastered:0,items:[{...q,streak:0}]};document.getElementById('dashboardContent').innerHTML=mistakesPanel();},fixture);
 await expect(page.locator('#dashboardContent svg')).toBeVisible();await expect(page.locator('#dashboardContent svg text')).toHaveText('Source graph');
 for(const surface of ['daily','drill','revision','exam']){
  await page.evaluate(({q,surface})=>{
   let out;
   if(surface==='daily'){DASH.daily={track:'sat',quiz:[q],checklist:{},leaderboard:[],completed:false};out=dailyPanel();}
   if(surface==='drill'){DASH.drill={drill_id:'test',topics:['Functions'],completed:false,questions:[q]};out=drillPanel();}
   if(surface==='revision'){REV.session={id:'test-revision',questions:[q],completed:false};out=revisionSessionPanel();}
   if(surface==='exam'){ST.run={exam:{track_id:'sat'},questions:[q]};ST.idx=0;ST.flags=new Set();renderQ();show('vRun');return;}
   document.getElementById('dashboardContent').innerHTML=out;
  },{q:fixture,surface});
  await expect(page.locator(surface==='exam'?'#qcard svg':'#dashboardContent svg')).toBeVisible();
 }
 expect(await page.evaluate(()=>window.__bad)).toBeUndefined();expect(errors).toEqual([]);expect(blocked).toEqual([]);
 await page.evaluate(()=>{ST.run.questions[0].assets.figure='https://math.portal.ghoneem.com/assets/question-figures/elite-m2-q21-20261004.png';renderQ();});
 const sourceGraph=page.locator('#qcard img');await expect(sourceGraph).toBeVisible();await expect(sourceGraph).toHaveJSProperty('naturalWidth',675);await expect(sourceGraph).toHaveJSProperty('naturalHeight',715);
 expect(errors).toEqual([]);expect(blocked).toEqual([]);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize().width+1);
});
