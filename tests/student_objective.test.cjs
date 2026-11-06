const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs'),vm=require('node:vm');
const html=fs.readFileSync('web/index.html','utf8');const code=html.slice(html.indexOf('let objectiveRequest'),html.indexOf('function show(id)'));
function fixture(data){const elements={};for(const id of ['chooserObjective','dashboardObjective','dashboardContent'])elements[id]={hidden:true,replaceChildren(){},querySelector(){return {}},insertBefore(){},prepend(){}};const q={select(){return this},eq(){return this},in:async()=>({data})};const c=vm.createContext({$:id=>elements[id],ST:{tracks:[{id:'sat'},{id:'est'}],track:{id:'est'}},sb:{from:()=>q},displayWeeklyObjective(){},document:{createElement:()=>({})},Intl,Date});vm.runInContext(code,c);return {c,elements};}
test('SAT and EST Today views retain planner access even without an assigned day',async()=>{for(const data of [null,[],[{title:'Algebra',track_id:'est',time_budget:'60 min'}]]){const f=fixture(data);for(const view of ['vTracks','vList']){await f.c.displayStudyObjective(view);const el=f.elements[view==='vTracks'?'chooserObjective':'dashboardObjective'];assert.equal(el.hidden,false);assert.match(el.innerHTML,/study-plan.html/);}}});
test('objectives are hidden during an exam',async()=>{const f=fixture([]);await f.c.displayStudyObjective('vRun');assert.equal(f.elements.dashboardObjective.hidden,true);});
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
async function linkedExam(exam,extra=[]){
 const dom=new JSDOM('<div id="dashboardContent"></div>',{runScripts:'outside-only',url:'https://portal.test/?study_track=sat&study_exam=linked'}),c=dom.getInternalVMContext();
 Object.assign(c,{ST:{tracks:[{id:'sat'}]},URLSearchParams,DASH:{exams:exam?[exam,...extra]:[]},openTrack:async()=>{},$:id=>dom.window.document.getElementById(id),esc:s=>String(s??''),wireDashboard(){},startExam(){throw Error('Must not auto-start');}});
 vm.runInContext(html.slice(html.indexOf('function assessmentRow('),html.indexOf('function assessmentSection(')),c);
 vm.runInContext(html.slice(html.indexOf('function moduleState('),html.indexOf('function fullExamSection(')),c);
 vm.runInContext(code,c);await c.openStudyLink();return dom;
}
test('study links reuse start, resume, review, closed and retake controls',async()=>{
 for(const [patch,label,disabled] of [[{},'Start',false],[{open:false},'Start',true],[{last:{id:'attempt',status:'in_progress'}},'Resume',false],[{last:{id:'attempt',status:'graded',score:2,total:3}},'Review',false]]){
  const dom=await linkedExam({id:'linked',title:'Quiz',assessment_type:'quiz',questions:3,duration_seconds:600,open:true,...patch});
  const button=dom.window.document.querySelector('button');assert.equal(button.textContent,label);assert.equal(button.disabled,disabled);if(label==='Review')assert.equal(button.dataset.review,'attempt');dom.window.close();
 }
 const dom=await linkedExam({id:'linked',title:'Quiz',assessment_type:'quiz',questions:3,duration_seconds:600,open:true,retake_available:true,last:{id:'a',status:'graded'}});assert.match(dom.window.document.body.textContent,/Start retake/);dom.window.close();
});
test('study links keep content holds and SAT module prerequisites',async()=>{
 for(const patch of [{content_ready:false},{exam_set_code:'set',module_number:2}]){
 const dom=await linkedExam({id:'linked',title:'Quiz',questions:3,duration_seconds:600,open:true,...patch},[{id:'first',exam_set_code:'set',module_number:1}]);assert.equal(dom.window.document.querySelector('button').disabled,true);dom.window.close();}
});
test('unassigned study links never offer a start action',async()=>{const dom=await linkedExam(null);assert.equal(dom.window.document.querySelector('button'),null);assert.match(dom.window.document.body.textContent,/not currently available/);dom.window.close();});
test('progress keys isolate students, tracks and activity; missing evidence stays unavailable',()=>{let js=fs.readFileSync('web/study-plan.js','utf8');const a=js.slice(js.indexOf('function evidence('),js.indexOf('function relevant('));const ctx=vm.createContext({progress:[{user_id:'a',track_id:'sat',study_date:'2026-11-05',activity:'lesson',status:'in_progress'}]});vm.runInContext(a,ctx);assert.equal(ctx.state({user_id:'a',track_id:'sat',study_date:'2026-11-05'},'lesson'),'in_progress');assert.equal(ctx.state({user_id:'b',track_id:'sat',study_date:'2026-11-05'},'lesson'),'unavailable');assert.equal(ctx.state({user_id:'a',track_id:'est',study_date:'2026-11-05'},'lesson'),'unavailable');assert.equal(ctx.state({user_id:'a',track_id:'sat',study_date:'2026-11-05'},'practice'),'unavailable');});

test('completed Alex objective remains visible after cutoff and opens its recorded result',async()=>{
 const {JSDOM}=require('./english-runtime/node_modules/jsdom');
 const dom=new JSDOM('<section id="chooserWeeklyObjective"></section><section id="dashboardWeeklyObjective"></section><div id="vList"></div>',{runScripts:'outside-only'});
 const c=dom.getInternalVMContext();Object.assign(c,{ST:{tracks:[{id:'est'}],track:{id:'est'}},objectiveRequest:1,$:id=>dom.window.document.getElementById(id),esc:x=>String(x),sb:{rpc:async()=>({data:{id:'exam',title:'Alex Algebra',open_at:new Date(Date.now()-3600000).toISOString(),close_at:new Date(Date.now()-60000).toISOString(),completed:true,attempt_id:'recorded-attempt',resume:false}})},openReview:async id=>c.reviewed=id,startExam:async()=>{throw Error('must not start another attempt')}});
 vm.runInContext(html.slice(html.indexOf('let weeklyRefresh;'),html.indexOf('let objectiveRequest =')),c);
 await c.displayWeeklyObjective('vList',1);
 const card=c.$('dashboardWeeklyObjective');assert.equal(card.hidden,false);assert.match(card.textContent,/Completed automatically/);
 const button=card.querySelector('button');assert.equal(button.textContent,'View quiz result');await button.onclick();assert.equal(c.reviewed,'recorded-attempt');dom.window.close();
});
