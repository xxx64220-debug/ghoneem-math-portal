const {test,expect}=require('@playwright/test');
const retest={id:'retest',title:'EST I Final Weakness Retest — Oct 2026',track_id:'est',is_published:true,assessment_type:'lesson_exam',question_ids:Array.from({length:25},(_,i)=>'q'+i),duration_seconds:2100};
const roster='abcdefgh'.split('').map(user_id=>({user_id,full_name:'Student '+user_id,role:'student',tracks:'est'}));
const evidence=['Circles','Linear equations','Statistics'].flatMap((lesson,i)=>['abcdef'[i*2],'abcdef'[i*2+1]].flatMap(user_id=>[
 {user_id,lesson,questions_seen:4,percent:20+i*10,track_id:'est'},
 {user_id,lesson:'Functions',questions_seen:3,percent:90,track_id:'est'}
]));
evidence.push({user_id:'g',lesson:'Circles',questions_seen:2,percent:0,track_id:'est'},
 {user_id:'h',lesson:'Circles',questions_seen:20,percent:0,track_id:'est'},
 {user_id:'h',lesson:'Functions',questions_seen:20,percent:0,track_id:'est'});
async function setup(page,context,{visible=true,resourceFailure=false,noRetest=false,examFailure=false}={}){
 const errors=[],unexpected=[],actions=[];page.on('pageerror',e=>errors.push(e.message));
 const fixtures={roster:[...roster,{user_id:'est2-only',full_name:'Other track',role:'student',tracks:'est2'}],results_feed:[],student_by_lesson:evidence,
 groups:[{id:'seven',name:'EST I class of seven',track_id:'est'},{id:'other',name:'Other class',track_id:'est'}],group_members:[...'abcdefg'].map(user_id=>({group_id:'seven',user_id})).concat([{group_id:'other',user_id:'h'}]),exams:noRetest?[]:[retest],assignments:[]};
 const revision={visible,items:['Circles','Linear equations','Statistics'].map(lesson=>({id:'revision-'+lesson,lesson,active:true,ready:true,difficulty:'easy',idea:'Fixture',stem:'Synthetic fixture'}))};
 await context.route('**/*',route=>{
  const url=new URL(route.request().url());if(url.origin==='http://127.0.0.1:4173')return route.continue();
  if(url.href==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.0/dist/umd/supabase.js')return route.fulfill({contentType:'application/javascript',body:`window.fixtureReads=[];window.supabase={createClient(){return {rpc:async(name,args)=>{const r=await fetch('https://wfhurjyouemahvkcfkdz.supabase.co/rest/v1/rpc/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(args)});const data=await r.json();return r.ok?{data,error:null}:{data:null,error:data};},auth:{getSession:async()=>({data:{session:{access_token:'local-staff-fixture'}}}),getUser:async()=>({data:{user:null}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from(table){const filters=[];let range=null;const query={select:()=>query,throwOnError:()=>query,eq:(k,v)=>{filters.push([k,v]);return query},order:()=>query,range:(a,b)=>{range=[a,b];return query},then(resolve,reject){window.fixtureReads.push(table);let data=(${JSON.stringify(fixtures)})[table]||[];for(const [k,v] of filters)data=data.filter(x=>x[k]===v);if(range)data=data.slice(range[0],range[1]+1);return Promise.resolve(${resourceFailure}&&['groups','group_members','exams'].includes(table)?{data:null,error:{message:'Offline'}}:{data,error:null}).then(resolve,reject)}};return query}}}};`});
  if(url.hostname==='fonts.googleapis.com'||(url.hostname==='cdn.jsdelivr.net'&&url.pathname.startsWith('/npm/katex@0.16.9/dist/')))return route.fulfill({body:'',contentType:route.request().resourceType()==='script'?'application/javascript':'text/css'});
  if(url.hostname==='wfhurjyouemahvkcfkdz.supabase.co'&&url.pathname==='/rest/v1/rpc/staff_group_exam_evidence'){
   const args=JSON.parse(route.request().postData());actions.push({action:'staff_group_exam_evidence',data:args});
   if(args.p_exam!=='retest'){unexpected.push(args.p_exam);return route.abort();}
   const students=args.p_students.map(user_id=>({user_id,state:user_id==='c'?'locked':user_id==='d'?'ungraded':user_id==='e'?'missing':'available',attempt:{id:'synthetic-'+user_id,attempt_no:2,submitted_at:'2026-10-04T12:00:00Z'},lessons:'cde'.includes(user_id)?[]:[
     {lesson:'Statistics',classified:true,seen:4,correct:3,missed:1,blank:1,percent:75},
     {lesson:'Functions',classified:true,seen:3,correct:3,missed:0,blank:0,percent:100},
     {lesson:'Limited',classified:true,seen:1,correct:0,missed:1,blank:0,percent:0}
   ]}));
   return route.fulfill(examFailure?{status:503,json:{message:'Offline'}}:{json:{exam_id:args.p_exam,track_id:'est',students}});
  }
  if(url.hostname==='wfhurjyouemahvkcfkdz.supabase.co'&&url.pathname==='/functions/v1/portal-controls'){
   const body=JSON.parse(route.request().postData());actions.push(body);
   if(body.action!=='revision.list'||body.data.track!=='est'){unexpected.push(body.action);return route.abort();}
   return route.fulfill(resourceFailure?{status:503,json:{error:'Offline'}}:{json:revision});
  }
  unexpected.push(url.href);return route.abort();
 });
 await page.goto('/admin.html');await page.waitForFunction(()=>!!document.querySelector('[data-v="finalsDiagnosisAdmin"]'));
 await page.evaluate(async()=>{ST.me={role:'instructor'};ST.tracks=[{id:'est',name:'EST Math'}];ST.view='finalsDiagnosisAdmin';await render();show(true);});
 return {errors,unexpected,actions};
}
test('group plan coordinates the saved seven-person class and opens existing lesson and retest views without writes',async({page,context},testInfo)=>{
 const audit=await setup(page,context);await page.locator('#finalsGroupView').click();
 const plan=page.locator('#finalsGroupPlan');await expect(plan).toContainText('7 students selected');
 await expect(page.locator('#finalsClass')).toHaveValue('seven');await expect(plan.locator('.finals-cluster')).toHaveCount(3);
 await expect(plan.locator('.finals-common')).toContainText('Circles · 2/7');await expect(plan.locator('.finals-insufficient')).toContainText('Student g');
 await expect(plan.locator('.finals-clusters')).not.toContainText('Student g');await expect(plan).not.toContainText('Student h');await expect(page.locator('#finalsGroup')).not.toContainText('Other track');
 await expect(plan.locator('.finals-cluster').first()).toContainText('25 questions · 35 minutes');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.screenshot({path:testInfo.outputPath('group-planning.png'),fullPage:true});
 await page.locator('#finalsStudentsView').click();await expect(page.locator('#finalsIndividual')).toBeVisible();await expect(page.locator('#finalsGroup')).toBeHidden();
 await expect(page.locator('#finalsIndividual')).toContainText('Individual question time not reliably tracked');
 await page.locator('#finalsGroupView').click();await expect(plan).toContainText('7 students selected');
 await page.locator('#finalsGroup summary').click();
 await page.locator('[data-finals-student="a"]').uncheck();await expect(plan).toContainText('6 students selected');await expect(plan.locator('.finals-cluster')).toHaveCount(2);
 await page.locator('#finalsClass').selectOption('other');await expect(plan).toContainText('1 students selected');await expect(plan.locator('.finals-common')).toContainText('Circles · 1/1');
 await page.locator('#finalsClass').selectOption('seven');await expect(plan.locator('.finals-cluster')).toHaveCount(3);
 await plan.locator('[data-finals-revision="Circles"]').click();await expect(page.locator('#revisionAdminLesson')).toHaveValue('Circles');
 await page.evaluate(async()=>{ST.view='finalsDiagnosisAdmin';await render();});await page.locator('#finalsGroupView').click();
 await page.locator('[data-finals-retest]').first().click();await expect(page.locator('#examSearch')).toHaveValue(retest.title);await expect(page.locator('#examTable tbody tr')).toHaveCount(1);
 expect(audit.actions.every(x=>x.action==='revision.list')).toBe(true);expect(audit.errors).toEqual([]);expect(audit.unexpected).toEqual([]);
 expect(await page.evaluate(()=>[localStorage.length,sessionStorage.length])).toEqual([0,0]);
});
test('hidden revision and missing retest are disclosed without invented practice links',async({page,context})=>{
 const audit=await setup(page,context,{visible:false,noRetest:true});await page.locator('#finalsGroupView').click();
 await expect(page.locator('#finalsGroupPlan')).toContainText('Final Revision is hidden from students.');
 await expect(page.locator('#finalsGroupPlan')).toContainText('October weakness retest is not currently published.');
 await expect(page.locator('[data-finals-revision]')).toHaveCount(0);await expect(page.locator('[data-finals-retest]')).toHaveCount(0);
 expect(audit.errors).toEqual([]);expect(audit.unexpected).toEqual([]);
});
test('resource failures keep student evidence available and allow manual class selection',async({page,context})=>{
 const audit=await setup(page,context,{resourceFailure:true});await page.locator('#finalsGroupView').click();
 await expect(page.locator('#finalsGroup')).toContainText('Saved class membership could not be loaded.');
 await page.locator('[data-finals-student="a"]').check();await page.locator('[data-finals-student="b"]').check();
 await expect(page.locator('#finalsGroupPlan')).toContainText('2 students selected');await expect(page.locator('.finals-cluster')).toHaveCount(1);
 await expect(page.locator('#finalsGroupPlan')).toContainText('Final Revision availability could not be checked.');
 await expect(page.locator('#finalsGroupPlan')).toContainText('Weakness retest availability could not be checked.');
 await page.locator('#finalsStudentsView').click();await expect(page.locator('#finalsIndividual')).toContainText('Student a');
 expect(audit.errors).toEqual([]);expect(audit.unexpected).toEqual([]);
});

test('selected exam plans use scored misses, separate locked and missing students, and return safely to Overall',async({page,context},testInfo)=>{
 const audit=await setup(page,context);await page.locator('#finalsGroupView').click();
 const plan=page.locator('#finalsGroupPlan');await expect(plan.locator('.finals-cluster')).toHaveCount(3);
 await page.locator('#finalsEvidenceScope').selectOption('retest');await expect(plan.locator('.finals-cluster')).toHaveCount(1);
 await expect(plan.locator('.finals-common')).toContainText('Statistics · 4/7');await expect(plan.locator('.finals-common')).toContainText('75%');await expect(plan.locator('.finals-common')).not.toContainText('Circles');
 await expect(plan.locator('.finals-insufficient')).toContainText('Student c');await expect(plan.locator('.finals-insufficient')).toContainText('review is locked');
 await expect(plan.locator('.finals-insufficient')).toContainText('awaiting grading');await expect(plan.locator('.finals-insufficient')).toContainText('No completed scored attempt');
 await expect(plan).toContainText('Attempt 2');await expect(plan).toContainText('Limited evidence: fewer than 3');await expect(plan).toContainText('1 unanswered');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.screenshot({path:testInfo.outputPath('group-selected-exam.png'),fullPage:true});
 await page.locator('#finalsGroup summary').click();await page.locator('[data-finals-student="a"]').uncheck();await expect(plan).toContainText('6 students selected');
 await page.locator('#finalsEvidenceScope').selectOption('');await expect(plan.locator('.finals-cluster')).toHaveCount(2);await expect(page.locator('#finalsEvidenceHint')).toContainText('Historical responses');
 const reads=audit.actions.filter(x=>x.action==='staff_group_exam_evidence');expect(reads).toHaveLength(2);expect(reads[0].data.p_students).toEqual([...'abcdefg']);expect(reads[1].data.p_students).toEqual([...'bcdefg']);
 expect(audit.errors).toEqual([]);expect(audit.unexpected).toEqual([]);expect(await page.evaluate(()=>[localStorage.length,sessionStorage.length])).toEqual([0,0]);
});
test('failed exam read shows retry without silently showing overall clusters',async({page,context})=>{
 const audit=await setup(page,context,{examFailure:true});await page.locator('#finalsGroupView').click();await page.locator('#finalsEvidenceScope').selectOption('retest');
 const plan=page.locator('#finalsGroupPlan');await expect(plan).toContainText('Could not load');await expect(plan.locator('.finals-cluster')).toHaveCount(0);
 await page.locator('#finalsExamRetry').click();await expect(plan).toContainText('Could not load');
 await page.locator('#finalsEvidenceScope').selectOption('');await expect(plan.locator('.finals-cluster')).toHaveCount(3);
 expect(audit.errors).toEqual([]);expect(audit.unexpected).toEqual([]);
});
