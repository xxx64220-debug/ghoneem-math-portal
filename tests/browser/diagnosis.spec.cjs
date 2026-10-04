const {test,expect}=require('@playwright/test');
const tracks=[{id:'est',name:'EST Math',exams_available:1,attempts_done:2}];
const exam={id:'exam-1',title:'Exam fixture',track_id:'est',assessment_type:'full_exam',duration_seconds:4500};
const history=[{id:'attempt-open',exam_id:'exam-1',title:'Reviewed exam',assessment_type:'full_exam',attempt_no:2,status:'graded',score:1,total:2,percent:50,review_open:true,submitted_at:'2026-10-02T08:00:00Z'},
{id:'attempt-locked',exam_id:'exam-1',title:'Locked exam',assessment_type:'full_exam',attempt_no:1,status:'graded',score:1,total:2,percent:50,review_open:false}];
const items=[{id:'circle-1',assets:{curriculum_lesson:'Circles'},is_correct:false,response:''},{id:'circle-2',assets:{curriculum_lesson:'Circles'},is_correct:true,response:'A'},
{id:'held',assets:{curriculum_lesson:'Circles'},is_correct:false,correct:{void:true}}];
const sdk=`window.supabase={createClient(){const session={access_token:'local-fixture',user:{id:'fixture-student'}};return {auth:{onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),getSession:async()=>({data:{session}}),getUser:async()=>({data:{user:session.user}})},from:()=>({select:()=>({gte:()=>({lt:async()=>{await new Promise(r=>setTimeout(r,100));return {data:[],error:null}}})})})}}};`;
test('exam diagnosis keeps evidence visible and opens lesson-focused Final Revision',async({page,context})=>{
 const errors=[],unexpected=[],reviewRequests=[];let revisionRequested=false;
 page.on('pageerror',e=>errors.push(e.message));
 await context.route('**/*', async route=>{
  const url=new URL(route.request().url());
  if(url.origin==='http://127.0.0.1:4173')return route.continue();
  
  if(url.href==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.0/dist/umd/supabase.js')return route.fulfill({contentType:'application/javascript',body:sdk});
  // Optional CDN styling/fonts/math are offline in this smoke test.
  if(url.hostname==='fonts.googleapis.com' || (url.hostname==='cdn.jsdelivr.net' && url.pathname.startsWith('/npm/katex@0.16.9/dist/')))return route.fulfill({body:'',contentType:route.request().resourceType()==='script'?'application/javascript':'text/css'});
  if(url.hostname==='wfhurjyouemahvkcfkdz.supabase.co' && url.pathname.startsWith('/functions/v1/')){
   const name=url.pathname.split('/').pop();let data;
   if(name==='me-tracks')data=url.search?{exams:[exam],dashboard:{history,lessons:[]}}:{role:'student',tracks};
   else if(name==='portal-controls')data={revision_visible:true};
   else if(name==='daily-challenge')data={date:'2026-10-02',reset_at:'2026-10-03T00:00:00Z',checklist:{quiz:false,focus:false,review:false},quiz:[],points_total:0};
   else if(name==='attempt-review'){const id=url.searchParams.get('attempt_id');reviewRequests.push(id);data={exam,review_open:true,items};}
   else if(name==='start-attempt'){const now=Date.now();data={exam:{...exam},attempt:{id:'smoke-attempt',server_now:new Date(now).toISOString(),deadline_at:new Date(now+2100000).toISOString()},questions};}
   else if(name==='exam-activity')data={accepted:JSON.parse(route.request().postData()).data.events.map(e=>e.id)};
   else if(name==='final-revision'){revisionRequested=true;data={items:[{id:'revision-circle',lesson:'Circles',idea:'Radius',source:'est',programmes:['est'],difficulty:'easy',focus:{collections:['must_know']}}]};}
   else {unexpected.push(url.href);return route.abort();}
   return route.fulfill({json:data});
  }
  unexpected.push(url.href);return route.abort();
 });

 await page.goto('/');await expect(page.locator('#listTitle')).toHaveText('EST Math');
 await page.locator('[data-view="finalsDiagnosis"]').click();
 await expect(page.locator('[data-diagnosis-exam="attempt-locked"]')).toBeDisabled();
 await expect(page.locator('.finals-diagnosis')).toContainText('0 active repeat-error questions');
 await page.locator('[data-diagnosis-exam="attempt-open"]').click();
 await expect(page.locator('.diagnosis-exams .lesson-card')).toHaveCount(1);
 await expect(page.locator('.diagnosis-exams .lesson-card')).toContainText('1/2 correct · 50%');
 await expect(page.locator('.diagnosis-exams .lesson-card')).toContainText('1 missed · 1 unanswered');
 await expect(page.locator('.diagnosis-exams .lesson-card')).toContainText('Limited evidence');
 await page.locator('.diagnosis-exams [data-diagnosis-revision="Circles"]').click();
 await expect(page.locator('.revision-panel')).toBeVisible();
 await expect(page.locator('[data-revision-filter="lesson"]')).toHaveValue('Circles');
 await expect(page.locator('[data-revision-collection="all"]')).toHaveClass(/active|selected|on/);
 expect(revisionRequested).toBe(true);expect(reviewRequests).toEqual(['attempt-open']);
 expect(errors).toEqual([]);expect(unexpected).toEqual([]);
});

test('instructor diagnosis downloads safe CSV from the displayed EST roster',async({page,context})=>{
 const unexpected=[],errors=[];page.on('pageerror',e=>errors.push(e.message));
 const fixtures={roster:[{user_id:'a',full_name:'=Student, "A"',tracks:'est, sat'},{user_id:'b',full_name:'No attempts',tracks:'est'},{user_id:'c',full_name:'Other track',tracks:'est2'}],results_feed:[{user_id:'a',score:1,total:4,percent:25,time_used:0}],student_by_lesson:[{user_id:'a',lesson:'Limited',questions_seen:2,percent:0},{user_id:'a',lesson:'Circles',questions_seen:3,percent:25}]};
 await context.route('**/*',route=>{
  const url=new URL(route.request().url());if(url.origin==='http://127.0.0.1:4173')return route.continue();
  if(url.href==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.0/dist/umd/supabase.js')return route.fulfill({contentType:'application/javascript',body:`window.supabase={createClient(){return {auth:{getSession:async()=>({data:{session:null}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from(table){const q={select:()=>q,throwOnError:()=>q,eq:()=>q,order:()=>q,range:(a,b)=>Promise.resolve({data:((${JSON.stringify(fixtures)})[table]||[]).slice(a,b+1)})};return q}}}};`});
  if(url.hostname==='fonts.googleapis.com'||(url.hostname==='cdn.jsdelivr.net'&&url.pathname.startsWith('/npm/katex@0.16.9/dist/')))return route.fulfill({body:'',contentType:route.request().resourceType()==='script'?'application/javascript':'text/css'});
  unexpected.push(url.href);return route.abort();
 });
 await page.goto('/admin.html');await page.waitForFunction(()=>!!document.querySelector('[data-v="finalsDiagnosisAdmin"]'));
 await page.evaluate(async()=>{ST.view='finalsDiagnosisAdmin';await render();document.getElementById('view').parentElement.classList.remove('hidden');});
 await expect(page.locator('#view')).toContainText('More evidence needed');
 const downloadPromise=page.waitForEvent('download');await page.locator('#finalsDiagnosisCsv').click();const download=await downloadPromise;
 expect(download.suggestedFilename()).toMatch(/^est-finals-diagnosis-\d{4}-\d{2}-\d{2}\.csv$/);
 const body=require('fs').readFileSync(await download.path(),'utf8');
 expect(body.startsWith('\ufeffstudent,latest_score,percent,time_seconds,')).toBe(true);
 expect(body).toContain('"\'=Student, ""A"""');expect(body).toContain('"1/4","25","0","Circles 25%"');
 expect(body).toContain('"No attempts","No completed EST attempt"');expect(body).not.toContain('Other track');expect(body).not.toContain('Limited');
 expect(errors).toEqual([]);expect(unexpected).toEqual([]);
});
