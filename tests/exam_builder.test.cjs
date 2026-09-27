const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const test=require('node:test');
const code=readFileSync('web/exam-builder.js','utf8');
const esc=s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const context={esc,window:{},console};
vm.createContext(context);
vm.runInContext(readFileSync('web/instructor-practice.js','utf8'),context);
vm.runInContext(code,context);
const questions=Array.from({length:2576},(_,i)=>({id:`q${i}`,track_id:'est',topic:i%2?'Geometry':'Algebra',difficulty:i%3?'medium':'hard',type:i%4?'mcq':'grid_in',stem:`Question ${i} with <unsafe> text`,choices:[{key:'A',text:'1/10'}],assets:{source_code:`EST-${i}`,image:`https://example.test/q${i}.png`}}));
questions.push({id:'sat1',track_id:'sat',topic:'Algebra',stem:'Other track',assets:{}});

test('every question including beyond 250 is reachable once, with bounded pages',()=>{
 const m=context.examPickerModel(questions,[],'est');
 const ids=[];
 for(let page=0;page<104;page++){m.page=page;const d=m.pageData();assert.ok(d.rows.length<=25);ids.push(...d.rows.map(q=>q.id));}
 assert.equal(ids.length,2576);assert.equal(new Set(ids).size,2576);assert.equal(ids.at(-1),'q2575');
 m.page=999;assert.equal(m.pageData().rows.length,1);assert.equal(m.page,103);
});
test('selection survives search, filter and page changes without moving bank rows',()=>{
 const m=context.examPickerModel(questions,['q2000'],'est');
 m.toggle('q3',true);m.toggle('sat1',true);assert.equal(m.selected.size,2);
 assert.equal(m.pageData().rows[0].id,'q0');
 m.search='EST-2575';assert.equal(m.pageData().rows[0].id,'q2575');m.toggle('q2575',true);
 m.topic='Algebra';assert.equal(m.pageData().total,0);
 m.selectedOnly=true;assert.deepEqual(Array.from(m.pageData().rows,q=>q.id),['q2000','q3','q2575']);
 m.move('q2575',-1);assert.deepEqual([...m.selected],['q2000','q2575','q3']);
 m.toggle('q2000',false);assert.deepEqual([...m.selected],['q2575','q3']);
 m.changeTrack('sat');assert.equal(m.selected.size,0);m.selectedOnly=false;m.search='';assert.equal(m.pageData().rows[0].id,'sat1');
});
test('held questions remain browsable but cannot be newly added',()=>{
 const q={...questions[0],assets:{release_hold_reason:'Missing diagram'}};
 const m=context.examPickerModel([q],[],'est');assert.equal(m.pageData().total,1);m.toggle(q.id,true);assert.equal(m.selected.size,0);
});
test('duplicate copies are identified separately from unresolved content',()=>{
 assert.equal(context.questionHoldLabel({assets:{release_hold_reason:'Duplicate of reviewed question q1'}}),'Duplicate');
 assert.equal(context.questionHoldLabel({assets:{release_hold_reason:'Missing diagram'}}),'Needs review');
});
test('adding a page respects the existing 200-question exam limit',()=>{
 const m=context.examPickerModel(questions,questions.slice(0,195).map(q=>q.id),'est');
 m.page=8;m.pageData().rows.forEach(q=>m.toggle(q.id,true));
 assert.equal(m.selected.size,200);assert.ok(m.selected.has('q204'));assert.ok(!m.selected.has('q205'));
 m.toggle('q0',false);m.toggle('q205',true);assert.equal(m.selected.size,200);assert.ok(m.selected.has('q205'));
});
test('preview includes full stem, matching graph, options, and escaped markup',()=>{
 const preview=context.examQuestionPreview(questions[2575]);
 assert.match(preview,/q2575\.png/);assert.doesNotMatch(preview,/q2574\.png/);
 assert.match(preview,/1\/10/);assert.match(preview,/&lt;unsafe&gt;/);assert.doesNotMatch(preview,/<unsafe>/);
});
test('create dialog opens with a disabled save button while the question bank loads',async()=>{
 const nodes=new Map(),node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',innerHTML:'',dataset:{},classList:{add(){},remove(){}},setAttribute(){},addEventListener(){},querySelectorAll(){return[]},querySelector(){return node('child')},scrollIntoView(){}});return nodes.get(id);};
 let release,opened=false;
 const pending=new Promise(resolve=>{release=resolve;});
 const c={...context,$:node,ST:{track:'est',tracks:[{id:'est',name:'EST'}]},getRows:()=>pending,field:()=>'',select:()=>'',area:()=>'',tracks:()=>[],val:id=>String(node(id).value),jval:()=>null,dialog(title,body){opened=true;node('editor').innerHTML=body;},mutation:async()=>{},alert:message=>{throw Error(message)}};
 vm.createContext(c);
 vm.runInContext(code,c);
 const opening=c.editExam();
 assert.equal(opened,true,'dialog is shown before waiting for the question bank');
 assert.match(node('editor').innerHTML,/Loading the question bank/);
 assert.equal(node('editSave').disabled,true);
 release(questions.slice(0,1));
 await opening;
 assert.equal(node('editSave').disabled,false);
});
test('changing track fetches that track before displaying its questions',async()=>{
 const nodes=new Map(),node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',innerHTML:'',dataset:{},classList:{add(){},remove(){}},setAttribute(){},addEventListener(){},querySelectorAll(){return[]},querySelector(){return node('child')},scrollIntoView(){}});return nodes.get(id);};
 const reads=[];
 const c={...context,$:node,ST:{track:'est',tracks:[{id:'est',name:'EST'},{id:'sat',name:'SAT'}]},getRows:async(...args)=>{reads.push(args);return questions.filter(q=>q.track_id===args[5]);},field:()=>'',select:()=>'',area:()=>'',tracks:()=>[],val:id=>String(node(id).value),jval:()=>null,dialog(title,body){node('editor').innerHTML=body;},mutation:async()=>{},confirm:()=>true,alert:message=>{throw Error(message)}};
 vm.createContext(c);vm.runInContext(code,c);
 await c.editExam();
 assert.deepEqual(reads[0],['questions',false,'*','id','track_id','est']);
 node('et').value='sat';
 await node('et').onchange();
 assert.deepEqual(reads[1],['questions',false,'*','id','track_id','sat']);
 assert.match(node('eqs').innerHTML,/Other track/);
 assert.doesNotMatch(node('eqs').innerHTML,/Question 0/);
});
test('editor saves selected IDs in chosen order and retains existing exam settings',async()=>{
 const nodes=new Map();
 const node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',innerHTML:'',dataset:{},classList:{add(){},remove(){}},setAttribute(){},addEventListener(){},querySelectorAll(selector){return id==='eqs'&&selector==='.builder-excerpt'?[node('excerpt')]:[]},querySelector(){return node('child')},scrollIntoView(){}});return nodes.get(id);};
 const rendered=[];
 const longStem='A complete equation must survive a long question. '.repeat(5)+'$y=\\frac{2x^2+12x+c}{3}$';
 const bankRows=questions.map(q=>q.id==='q2575'?{...q,stem:longStem}:q);
 let onSave,saved;const reads=[];
 const c={...context,window:{renderMathInElement:(el,options)=>rendered.push({el,options})},$:node,ST:{track:'est',tracks:[{id:'est',name:'EST'}]},getRows:async(...args)=>{reads.push(args);return bankRows;},
  field:()=>'',select:()=>'',area:()=>'',tracks:()=>[],val:id=>String(node(id).value),jval:()=>({0:200,2:800}),
  dialog(title,body,save){onSave=save;node('editor').innerHTML=body;},mutation:async(action,data)=>{saved={action,data};},confirm:()=>true,alert:message=>{throw Error(message)}};
 vm.createContext(c);vm.runInContext(code,c);
 await c.editExam({id:'exam1',track_id:'est',question_ids:['q2000','q2'],title:'Revision',duration_seconds:3600,assessment_type:'full_exam',is_published:true});
 assert.deepEqual(reads[0],['questions',false,'*','id','track_id','est'],'builder fetches only the exam track');
 node('etitle').value='Revision';node('emins').value='60';node('etype').value='full_exam';node('ereview').value='score_only';
 node('efilter').value='EST-2575';node('efilter').oninput();assert.match(node('eqs').innerHTML,/q2575/);
 assert.ok(node('eqs').innerHTML.includes(esc(longStem)),'excerpt retains complete math source beyond the old 220-character cutoff');
 assert.ok(rendered.some(call=>call.el===node('excerpt')&&call.options.delimiters.some(d=>d.left==='$')),'visible excerpts are passed through the math renderer');
 node('eaddPage').onclick();node('ereviewSelected').onclick();assert.match(node('eqs').innerHTML,/Selected · #3/);
 await onSave();assert.equal(saved.action,'exam.save');assert.deepEqual(Array.from(saved.data.question_ids),['q2000','q2','q2575']);
 assert.equal(saved.data.duration_seconds,3600);assert.equal(saved.data.is_published,true);assert.equal(saved.data.review_policy,'score_only');assert.equal(saved.data.scoring_map[2],800);
});
