const fs=require('fs'),assert=require('assert');
const student=fs.readFileSync('web/portal-controls.js','utf8');
const admin=fs.readFileSync('web/hardest-questions.js','utf8');
assert(student.includes("b.dataset.view='finalsDiagnosis'"),'student finals diagnosis tab missing');
assert(student.includes('Not individually measured'),'student UI must not invent per-question timing');
assert(student.includes('C / A / R / D / T / X'),'student error-code legend missing');
assert(student.includes('Do not immediately reteach everything missed'),'student diagnosis workflow missing');
assert(admin.includes("finalsDiagnosisAdmin"),'admin finals diagnosis report missing');
assert(admin.includes('Individual question time not reliably tracked'),'admin must disclose timing limitation');
assert(admin.includes('Bottom 2–3 skills / topic accuracy'),'admin diagnosis columns missing');
assert(admin.includes('C/A/R/D/T/X'),'admin error-code legend missing');
console.log('finals diagnosis regression checks passed');

assert(student.includes('data-diagnosis-revision'),'diagnosis must link weak skills to Final Revision');
assert(student.includes("REV.lesson=lesson"),'diagnosis must focus Final Revision on selected weak lesson');
assert(student.includes("REV.collection='all'"),'diagnosis practice must use the existing full curated revision bank');

// Async notebook loading must preserve diagnosis and its wired revision action.
const vm=require('node:vm');
const {test}=require('node:test');
for(const failed of [false,true])test(`diagnosis survives notebook ${failed?'failure':'success'} and opens focused revision`,async()=>{
 let resolveNotebook,calls=0,refreshes=0,paints=0;
 const result=new Promise(resolve=>{resolveNotebook=resolve;});
 const content={innerHTML:''};let buttons=[];
 const document={getElementById:()=>content,querySelector:()=>null,querySelectorAll:selector=>{
  if(selector!=='[data-diagnosis-revision]')return [];
  buttons=[...content.innerHTML.matchAll(/data-diagnosis-revision="([^"]+)"/g)].map(m=>({dataset:{diagnosisRevision:m[1]}}));return buttons;
 }};
 const c={document,ST:{track:{id:'est'}},DASH:{view:'finalsDiagnosis',lessons:[{lesson:'Linear equations',seen:4,correct:1,percent:25,priority:'focus'}],history:[],exams:[]},esc:String,REV:{data:null},paintDashboard(){},paintDashboardContent(){content.innerHTML='Generic focus';},wireDashboard(){},setDashboardView(view){c.DASH.view=view;},async refreshRevision(){refreshes++;c.REV.data={items:[]};},revisionPaint(){paints++;},sb:{from:()=>{calls++;return {select:()=>({gte:()=>({lt:()=>result})})};}}};
 vm.createContext(c);vm.runInContext(student.slice(student.indexOf('(function(){')),c);
 c.paintDashboardContent();assert(content.innerHTML.includes('Finals diagnosis'));assert.equal(buttons.length,1);
 resolveNotebook(failed?{error:new Error('Offline')}:{data:[{}],error:null});
 await new Promise(resolve=>setImmediate(resolve));
 assert(content.innerHTML.includes('Finals diagnosis'));assert.equal(buttons.length,1);assert.equal(calls,1,'failed loads must not loop');
 await buttons[0].onclick();assert.equal(c.DASH.view,'revision');assert.equal(c.REV.lesson,'Linear equations');assert.equal(c.REV.collection,'all');assert.equal(c.REV.level,'mixed');assert.equal(refreshes,1);assert.equal(paints,1);
});

const lessonContext={};vm.createContext(lessonContext);vm.runInContext(student.slice(student.indexOf('function finalsExamLessons'),student.indexOf('/* ===================== EST FINALS DIAGNOSIS')),lessonContext);
test('exam study plan uses graded results, explicit lessons and distinct question IDs',()=>{
 const rows=lessonContext.finalsExamLessons([
  {id:'a',assets:{curriculum_lesson:'Circles'},is_correct:false,response:''},
  {id:'b',assets:{curriculum_lesson:'Circles'},is_correct:true,response:'A'},
  {id:'b',assets:{curriculum_lesson:'Circles'},is_correct:true,response:'A'},
  {id:'held',assets:{curriculum_lesson:'Circles'},is_correct:false,correct:{void:true}},
  {id:'pending',assets:{curriculum_lesson:'Circles'},is_correct:null},
  {id:'untagged',is_correct:false,response:'B'},
  {id:'topic',topic:'Triangles and similarity',is_correct:true}
 ]);
 const circles=rows.find(x=>x.lesson==='Circles');assert.equal(circles.seen,2);assert.equal(circles.correct,1);assert.equal(circles.percent,50);assert.equal(circles.blank,1);
 assert.equal(rows.find(x=>x.lesson==='Unclassified questions').classified,false);assert.equal(rows.length,3);
});

test('empty and ungraded reviews have no study evidence',()=>{assert.equal(lessonContext.finalsExamLessons([]).length,0);assert.equal(lessonContext.finalsExamLessons([{id:'pending',is_correct:null}]).length,0);assert(student.includes('No scored question evidence is available yet.'));});
