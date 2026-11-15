// Isolated browser QA with production markup/styles/scripts and synthetic records.
// No authentication, network APIs, real student data or production write path.
const fs=require('node:fs'),path=require('node:path'),{JSDOM}=require('../english-runtime/node_modules/jsdom');
const root=path.resolve('.sites-runtime/planner-qa'),dist=path.join(root,'dist');fs.mkdirSync(dist,{recursive:true});fs.mkdirSync(path.join(root,'.openai'),{recursive:true});fs.writeFileSync(path.join(root,'.openai/hosting.json'),JSON.stringify({static:{directory:'dist'}}));
const read=n=>fs.readFileSync('web/'+n,'utf8');
for(const mode of ['instructor','student']){
 const dom=new JSDOM(read('study-plan.html')),d=dom.window.document;
 for(const script of d.querySelectorAll('script'))script.remove();
 for(const link of d.querySelectorAll('link')){const href=link.getAttribute('href');if(link.rel==='stylesheet'&&href.startsWith('/')&&fs.existsSync('web/'+href.split('?')[0])){const style=d.createElement('style');style.textContent=read(href.split('?')[0].slice(1));link.replaceWith(style);}else link.remove();}
 const add=code=>{const script=d.createElement('script');script.textContent=code;d.body.append(script);};
 add('const supabase={createClient:()=>({})}; window.history.replaceState=(function(original){return function(...args){return original.apply(history,args);};})(window.history.replaceState);');
 add(read('study-plan.js').replace(/boot\(\);\s*$/,''));
 add(`
 me={id:'${mode==='instructor'?'teacher':'one'}'};staff=${mode==='instructor'};ready=true;loading=false;initialContextPending=false;followToday=false;
 $('date').value='2026-11-17';$('track').value='est';$('workspace').hidden=false;
 if(staff){$('back').href='/admin.html';$('back').textContent='← Instructor console';}
 for(const id of ['groupLabel','studentLabel','edit'])$(id).hidden=!staff;
 groups=[{id:alexSchedule.group,track_id:'est',name:'Alex EST I',plan_version:1,target_exam_date:'2026-12-11',teaching_plan:'November 16–22: statistics and probability.\\nNovember 23–29: geometry and trigonometry.'}];
 members=[{group_id:alexSchedule.group,user_id:'one'}];students=[{user_id:'one',full_name:'Example student'}];
 $('group').innerHTML='<option value="">All groups</option><option value="'+alexSchedule.group+'">Alex EST I</option>';$('group').value=alexSchedule.group;selectStudents();
 plans=[{user_id:'one',track_id:'est',study_date:'2026-11-17',title:'Turn mistakes into a stronger method',instructions:'Group: Alex EST I\\nReview percentages, then explain the method used in each solution.',lesson:'Percentages & linear equations',time_budget:'Up to 60 minutes',calculator_allowed:true,destination:'practice',practice_source:'exam',lesson_exam_id:'lesson',practice_exam_id:'weekly',retest_exam_id:null,skipped_activities:[]}];
 progress=[{user_id:'one',track_id:'est',study_date:'2026-11-17',activity:'lesson',status:'completed',submitted_at:'2026-11-17T09:00:00Z'},{user_id:'one',track_id:'est',study_date:'2026-11-17',activity:'practice',status:'pending'},{user_id:'one',track_id:'est',study_date:'2026-11-17',activity:'retest',status:'needs_link'}];
 exams=assignedAssessments=[{id:'lesson',title:'Percentages — lesson check',is_published:true},{id:'weekly',title:'Alex EST I — Tuesday Algebra · 10Q · 20 min',is_published:true}];
 scheduleAssignments=[{id:'a',exam_id:'weekly',group_id:alexSchedule.group,open_at:'2026-11-17T11:10:00Z',close_at:'2026-11-17T11:30:00Z',exams:{...exams[1],duration_seconds:1200}},{id:'b',exam_id:'lesson',user_id:'one',open_at:'2026-11-16T22:00:00Z',close_at:'2026-11-17T21:59:00Z',exams:{...exams[0],duration_seconds:900}}];
 scheduleVerified=assessmentMetadataVerified=enrollmentVerified=true;enrollmentWindows=[{user_id:'one',track_id:'est',status:'active'}];
 sb.from=table=>{const q={select:()=>q,eq:()=>q,in:()=>q,order:()=>q,range:async()=>({data:table==='exams'?exams:plans,error:null}),upsert:()=>({select:async()=>({data:null,error:{message:'QA fixture: publication is disabled'}})})};return q;};
 sb.rpc=async()=>({error:{message:'QA fixture: publication is disabled'}});
 load=async()=>{render();return true};
 `);
 add(read('planner-workspace.js'));add(read('portal-navigation.js'));add("render();$('message').textContent='QA preview · Synthetic data only. Publishing is disabled.';");
 fs.writeFileSync(path.join(dist,mode+'.html'),dom.serialize());dom.window.close();
}
fs.writeFileSync(path.join(dist,'index.html'),`<!doctype html><html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Planner QA</title><style>body{margin:0;padding:16px;background:#ebeae5;color:#14243e;font:14px system-ui}iframe{border:1px solid #ccc;border-radius:10px;background:white;display:block;margin:16px 0;max-width:100%}a{color:inherit;margin-right:20px}</style><h1>December planner · isolated preview</h1><p>Production UI · synthetic records · no production writes</p><a href="instructor.html">Instructor full page</a><a href="student.html">Student full page</a><h2>Mobile student · 390px</h2><iframe title="Mobile student" src="student.html" width="390" height="1000"></iframe><h2>Desktop instructor</h2><iframe title="Desktop instructor" src="instructor.html" width="1100" height="1100"></iframe></html>`);
console.log(root);
