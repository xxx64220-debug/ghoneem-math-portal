const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function client(){
 const nodes=new Map(),node=id=>{if(!nodes.has(id))nodes.set(id,{id,value:'',textContent:'',innerHTML:'',disabled:false,style:{},classList:{toggle(){},contains(){return true},remove(){},add(){}},querySelectorAll(){return[]}});return nodes.get(id);};
 const c={console,Map,Set,Date,JSON,Promise,Number,String,Array,Object,Math,Error,RegExp,URL,crypto:require('node:crypto').webcrypto,setInterval(){},clearInterval(){},setTimeout(){},clearTimeout(){},alert(){},confirm(){return true},location:{},localStorage:{setItem(){},getItem(){return null}},document:{addEventListener(){},getElementById:node,querySelectorAll(){return[]}},window:{addEventListener(){},scrollTo(){}},supabase:{createClient:()=>({auth:{getSession:async()=>({data:{session:null}}),getUser:async()=>({data:{user:null}})}})}};
 vm.createContext(c);vm.runInContext(fs.readFileSync('web/index.html','utf8').split('<script>')[1].split('</script>')[0],c);
 vm.runInContext("ST.track={id:'sat'};readingQuestion=(it,track,after,stem)=>stem+after;reportButton=()=>'';",c);
 return {c,node,run:s=>vm.runInContext(s,c)};
}
const items=n=>Array.from({length:22},(_,i)=>({id:`m${n}q${i}`,stem:`Module ${n} question ${i+1}`,type:'mcq',choices:[{key:'A',text:'4'},{key:'B',text:'8'}],response:'B',correct:'A',is_correct:false,explanation:'Divide both sides by 2.'}));
const result=()=>({full_exam:true,exam:{title:'SAT practice'},attempt:{score:35,total:44},modules:[{module_number:1,attempt:{score:17,total:22},review_open:true,items:items(1)},{module_number:2,attempt:{score:18,total:22},review_open:true,items:items(2)}]});
test('SAT full exam review renders 44 questions under both module headings and the combined score',()=>{
 const f=client();f.c.result=result();f.run('paintReview(result)');const html=f.node('vReview').innerHTML;
 assert.match(html,/35\/44/);assert.match(html,/Full exam · Module 1 \+ Module 2/);assert.match(html,/17\/22/);assert.match(html,/18\/22/);
 assert.match(html,/id="reviewModule1"/);assert.match(html,/id="reviewModule2"/);assert.equal((html.match(/class="rev wrong"/g)||[]).length,44);
 assert.match(html,/Module 1 question 22/);assert.match(html,/Module 2 question 22/);assert.equal((html.match(/Your answer:/g)||[]).length,44);assert.equal((html.match(/Divide both sides by 2/g)||[]).length,44);
 assert.equal((html.match(/>22 · INCORRECT/g)||[]).length,2,'numbering restarts within each module');
});
test('locked module keeps its own notice and does not hide the other module',()=>{
 const f=client();f.c.result=result();f.c.result.modules[0]={module_number:1,attempt:{score:17,total:22},review_open:false,items:[]};f.run('paintReview(result)');
 const html=f.node('vReview').innerHTML;assert.match(html,/Answers open later/);assert.doesNotMatch(html,/Module 1 question/);assert.match(html,/Module 2 question 22/);
});
test('review link and post-submission result use the same full exam rendering',async()=>{
 const f=client();f.c.result=result();f.c.calls=[];f.run("fn=async(name,options)=>{calls.push({name,options});return {ok:true,json:result}};");
 await f.run("openReview('module-two-attempt')");assert.equal(f.c.calls[0].name,'attempt-review');assert.equal(f.c.calls[0].options.qs,'?attempt_id=module-two-attempt');assert.match(f.node('vReview').innerHTML,/Module 1 question 22/);
 f.run("ST.run={attempt:{id:'module-two-attempt'},exam:{id:'module-two'},questions:[]};captureInput=()=>{};persistPending=()=>{};");await f.run('submitExam(false)');assert.equal(f.c.calls[1].name,'submit-attempt');assert.match(f.node('vReview').innerHTML,/35\/44/);assert.match(f.node('vReview').innerHTML,/Module 1 question 22/);
});
test('full exam card has a clear review action, while incomplete and single papers keep their controls',()=>{
 const f=client();f.run("DASH.exams=[1,2].map(n=>({id:'m'+n,title:'SAT practice — Module '+n,assessment_type:'full_exam',exam_set_code:'pair',module_number:n,questions:22,duration_seconds:2100,open:true,last:{id:'a'+n,status:'graded',score:17,total:22}}));");
 assert.match(f.run('fullExamSection()'),/data-review="a2">Review full exam/);
 f.run('DASH.exams[1].last=null');assert.doesNotMatch(f.run('fullExamSection()'),/>Review full exam/);
 f.c.result={full_exam_pending:true,exam:{title:'SAT practice — Module 1'},attempt:{score:17,total:22},review_open:false,items:[]};f.run("paintReview(result,'m2')");assert.match(f.node('vReview').innerHTML,/Complete both modules/);assert.match(f.node('vReview').innerHTML,/Start Module 2/);
 f.c.result={exam:{title:'EST <exam>'},attempt:{score:17,total:22},review_open:true,items:items(1)};f.run('paintReview(result)');assert.match(f.node('vReview').innerHTML,/EST &lt;exam&gt;/);assert.doesNotMatch(f.node('vReview').innerHTML,/Full exam · Module 1/);
});
test('October source routes keep their actual counts and explain the shared fixed baseline',()=>{
 const f=client();
 for(const [paper,route,counts] of [[1,'easy',[24,25]],[1,'hard',[24,27]],[2,'easy',[22,22]],[2,'hard',[22,22]]]){
  f.c.routeRows=counts.map((n,i)=>({id:`p${paper}-${route}-m${i+1}`,title:`SAT Trial 2026 October — Paper ${paper} · ${route} route — Module ${i+1}`,assessment_type:'full_exam',exam_set_code:`sat-october-2026-paper-${paper}-${route}`,module_number:i+1,questions:n,duration_seconds:2100,open:true,last:{id:'a'+i,status:'graded',score:n-1,total:n}}));
  f.run('DASH.exams=routeRows');const html=f.run('fullExamSection()');
  assert.ok(html.includes(`${counts[0]} + ${counts[1]} questions`));
  assert.ok(html.includes(`${counts[0]+counts[1]-2}/${counts[0]+counts[1]}`));
  assert.match(html,/35 \+ 35 minutes/);assert.match(html,/choose one Easy or Hard route/);
  assert.match(html,/your score does not choose the next module/);assert.match(html,/share Module 1/);
  assert.match(html,/without an official SAT scaled score/);
 }
 f.run("DASH.exams=[1,2].map(n=>({id:'standard-'+n,title:'SAT standard — Module '+n,assessment_type:'full_exam',exam_set_code:'standard',module_number:n,questions:22,duration_seconds:2100,open:true}));");
 const standard=f.run('fullExamSection()');assert.doesNotMatch(standard,/choose one Easy or Hard route/);assert.match(standard,/22 \+ 22 questions/);
});
