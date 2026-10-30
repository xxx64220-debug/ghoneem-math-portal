const {fixtureDocument}=require('./fixture-document.cjs');

// Entire admin page and real render/assign/group/bulk functions run unchanged.
// Only the SDK/network boundary is synthetic. Unknown requests fail closed.
function data(){
 const exams=[1,2].map(n=>({id:'fixture-exam-'+n,title:'Assignment browser fixture '+n,track_id:'est',assessment_type:'quiz',is_published:true,question_ids:['fixture-question'],duration_seconds:1200}));
 const roster=Array.from({length:1105},(_,i)=>({user_id:'student-'+i,full_name:'Student '+String(i).padStart(4,'0'),email:'student'+i+'@example.test',role:'student',status:'active',tracks:'est'}));
 roster[1104].full_name='LongStudentName'.repeat(12);roster[1104].email='long'.repeat(45)+'@example.test';
 roster.push({user_id:'other-track',full_name:'Other track',role:'student',status:'active',tracks:'sat'},{user_id:'suspended',full_name:'Suspended',role:'student',status:'suspended',tracks:'est'});
 const groups=[{id:'group-a',name:'Sunday fixture',track_id:'est',instructor_id:'fixture-teacher'},{id:'group-b',name:'Wednesday fixture',track_id:'est',instructor_id:'fixture-teacher'},{id:'other-teacher',name:'Other teacher fixture',track_id:'est',instructor_id:'someone-else'},{id:'other-track',name:'SAT fixture',track_id:'sat',instructor_id:'fixture-teacher'}];
 const group_members=[0,1,2].map(i=>({group_id:'group-a',user_id:'student-'+i})).concat([1,2,3].map(i=>({group_id:'group-b',user_id:'student-'+i})),roster.slice(4,1105).map(r=>({group_id:'other-teacher',user_id:r.user_id})));
 return {exams,roster,groups,group_members,assignments:[]};
}
function sdk(){return `window.supabase={createClient(){return {
 auth:{getSession:async()=>({data:{session:{access_token:'synthetic-assignment-fixture'}}}),getUser:async()=>({data:{user:null}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
 from(table){const filters=[];let range=null;const q={select:()=>q,eq:(key,value)=>{filters.push([key,value]);return q},order:()=>q,range:(a,b)=>{range=[a,b];return q},then(resolve,reject){return fetch('/__assignment_fixture_read',{method:'POST',body:JSON.stringify({table,filters,range})}).then(r=>r.json()).then(resolve,reject)}};return q},
 rpc:async name=>{throw new Error('Unexpected fixture RPC: '+name)}
}}};`;}
async function setup(page,context,{role='admin',existing=[],fail,readFailure=false}={}){
 const fixtures=data();fixtures.assignments=structuredClone(existing);
 const audit={calls:[],reads:[],unexpected:[],errors:[],fixtures,fail,readFailure};
 page.on('pageerror',e=>audit.errors.push(e.message));
 await context.route('**/*',async route=>{
  const request=route.request(),url=new URL(request.url());
  if(url.origin==='http://127.0.0.1:4173'){
   if(url.pathname==='/__assignment_fixture_read'){
    const {table,filters,range}=request.postDataJSON();audit.reads.push({table,range});
    if(table==='assignments'&&audit.readFailure)return route.fulfill({json:{data:null,error:{message:'Synthetic readback unavailable'}}});
    if(!Object.hasOwn(fixtures,table)){audit.unexpected.push('table:'+table);return route.abort();}
    let rows=fixtures[table];for(const [k,v] of filters)rows=rows.filter(r=>r[k]===v);
    if(range)rows=rows.slice(range[0],range[1]+1);
    return route.fulfill({json:{data:rows,error:null}});
   }
   // Never forward a mutation to the preview server.
   if(!['GET','HEAD'].includes(request.method())){audit.unexpected.push(request.method()+' '+url.href);return route.abort();}
   return fixtureDocument(route);
  }
  if(url.href==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.50.0/dist/umd/supabase.js')return route.fulfill({contentType:'application/javascript',body:sdk()});
  if(url.hostname==='fonts.googleapis.com'||(url.hostname==='cdn.jsdelivr.net'&&url.pathname.startsWith('/npm/katex@0.18.2/dist/')))return route.fulfill({body:'',contentType:request.resourceType()==='script'?'application/javascript':'text/css'});
  if(url.hostname==='wfhurjyouemahvkcfkdz.supabase.co'&&url.pathname==='/functions/v1/staff-console'){
   const body=request.postDataJSON();audit.calls.push(body);
   if(body.action!=='assignment.save'||!fixtures.exams.some(e=>e.id===body.data.exam_id)){audit.unexpected.push(body);return route.abort();}
   if(audit.gate)await audit.gate;
   const result=audit.fail?.(body,audit);
   if(result==='reject')return route.fulfill({status:503,json:{error:'Synthetic connection interruption'}});
   if(fixtures.assignments.some(a=>a.exam_id===body.data.exam_id&&(body.data.group_id?a.group_id===body.data.group_id:a.user_id===body.data.user_id)))return route.fulfill({status:409,json:{error:'Synthetic uniqueness conflict'}});
   fixtures.assignments.push({id:'fixture-assignment-'+fixtures.assignments.length,...body.data});
   if(result==='lost')return route.abort('failed');
   return route.fulfill({json:{ok:true}});
  }
  audit.unexpected.push(url.href);return route.abort();
 });
 await page.goto('/admin.html');
 await page.waitForFunction(()=>window.ExamAssignments&&window.GroupManager&&window.AdminBulk);
 await page.evaluate(async role=>{ST.me={id:'fixture-teacher',role};ST.tracks=[{id:'est',name:'EST Math'}];ST.track='est';ST.view='exams';await render();show(true);},role);
 return audit;
}
module.exports={setup,data,sdk};
