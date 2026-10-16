const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');const source=fs.readFileSync('web/portal-management.js','utf8');
const flush=()=>new Promise(r=>setImmediate(r));
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function setup(role='admin',lessonOptions){
 const dom=new JSDOM('<nav id="tabs"><div class="wrap"></div></nav><select id="adminSection"></select><main id="app"><div id="view"></div></main><dialog id="editor"></dialog>',{runScripts:'outside-only',url:'https://local.test'}),w=dom.window,calls=[];let save;
 w.ST={view:'subscriptions',track:'sat',me:{role},tracks:[{id:'sat',name:'SAT'}]};w.esc=esc;w.render=async()=>{};w.syncAdminNavigation=()=>{};
 w.$=id=>w.document.getElementById(id);w.val=id=>w.$(id).value.trim();w.wrapTable=x=>x;w.csv=(rows,name)=>calls.push({csv:rows,name});w.alert=m=>calls.push({alert:m});
 w.field=(id,label,value='',type='text')=>`<label for="${id}">${label}</label><input id="${id}" type="${type}" value="${esc(value)}">`;
 w.select=(id,label,opts,value='')=>`<label>${label}<select id="${id}">${opts.map(([v,t])=>`<option value="${v}" ${v===value?'selected':''}>${t}</option>`).join('')}</select></label>`;
 w.area=(id,label,value='')=>`<label>${label}<textarea id="${id}">${esc(value)}</textarea></label>`;
 w.dialog=(title,html,onSave)=>{save=onSave;w.$('editor').innerHTML=html;};
 w.getRows=async()=>[{id:'g',track_id:'sat',name:'SAT November',plan_version:0,daily_lessons:['Algebra'],teaching_plan:'Diagnose',target_exam_date:null}];
 w.sb={rpc:async(name,args)=>{calls.push({name,args});if(name==='admin_course_enrollments')return {data:{total:1,summary:{active:1},items:[{user_id:'s',track_id:'sat',full_name:'<script>bad()</script>',email:'s@example.test',status:'active',access_state:'active',account_status:'active',course_label:'SAT November',starts_at:null,ends_at:null,payment_status:'unrecorded',access_version:0}]}};
 if(name==='staff_course_lessons')return {data:lessonOptions||['Algebra','Geometry']};
 if(name==='staff_bank_operations')return {data:{total:1,summary:{total:1,students:1},items:[{id:'q',code:'TEST',lesson:'Algebra',stem:'<img onerror="bad()">',ready:true,reserve:false,math_review:'independently_solved',unique_students:2,responses:3,first_success:0,latest_success:50,repeat_improvement:100,repeat_candidates:1,improved:1,published_exams:1,assignments:1,assets_hash:'hash'}]}};
 return {data:{}};},from(){return {select(){return this;},eq(){return this;},order(){return Promise.resolve({data:[{id:'c',track_id:'sat',title:'Previous trial',ends_at:'2026-10-09'}]});}}}};
 w.eval(source);return {w,dom,calls,get save(){return save;}};
}
test('administrator sees course controls, dates renew correctly, receipts reuse request IDs',async()=>{
 const s=setup();await s.w.render();assert.ok(s.w.$('courseFilter'));assert.equal(s.w.document.querySelector('#view script'),null);
 s.w.document.querySelector('[data-access]').click();s.w.$('courseLabel').value='Next SAT';s.w.$('coursePayment').value='waived';await s.save();
 const saved=s.calls.find(x=>x.name==='admin_save_course_access');assert.equal(saved.args.p_expected_version,0);assert.equal(saved.args.p_data.ends_at,null);assert.equal(saved.args.p_data.payment_status,'waived');
 s.w.document.querySelector('[data-payment]').click();s.w.$('paymentAmount').value='400';s.w.$('paymentReference').value='Receipt';await s.save();await s.save();
 const payments=s.calls.filter(x=>x.name==='admin_record_course_payment');assert.equal(payments.length,2);assert.equal(payments[0].args.p_request,payments[1].args.p_request);assert.equal(payments[0].args.p_amount,400);
 s.w.$('paymentAmount').value='-1';await assert.rejects(()=>s.save(),/positive amount/);s.dom.window.close();
});
test('instructor cannot open billing and receives only teaching destinations',async()=>{
 const s=setup('instructor');await s.w.render();assert.match(s.w.$('view').textContent,/administrator/);assert(!s.calls.some(x=>x.name==='admin_course_enrollments'));
 assert(s.w.document.querySelector('[data-v="subscriptions"]').hidden);
 s.w.ST.view='coursePlans';await s.w.render();s.w.document.querySelector('[data-plan]').click();await flush();assert.equal(s.w.$('editor').querySelectorAll('[data-plan-lesson]').length,2);
 s.w.$('planText').value='Reteach algebra, worksheet, quiz and retest';await s.save();const p=s.calls.find(x=>x.name==='staff_save_group_plan');assert.deepEqual(JSON.parse(JSON.stringify(p.args.p_data.daily_lessons)),['Algebra']);s.dom.window.close();
});
test('group/cycle/filter scopes queries; small samples and improvement denominator are visible',async()=>{
 const s=setup();s.w.ST.view='bankOperations';await s.w.render();assert.match(s.w.$('view').textContent,/Small sample/);assert.match(s.w.$('view').textContent,/1\/1 initially wrong repeaters/);assert.equal(s.w.$('view').querySelector('img'),null);
 s.w.$('opsGroup').value='g';s.w.$('opsGroup').onchange({target:s.w.$('opsGroup')});await flush();
 s.w.$('opsCycle').value='c';s.w.$('opsCycle').onchange({target:s.w.$('opsCycle')});await flush();
 const last=s.calls.filter(x=>x.name==='staff_bank_operations').at(-1);assert.equal(last.args.p_group,'g');assert.equal(last.args.p_cycle,'c');
 s.w.document.querySelector('[data-reserve]').click();s.w.$('reserveReason').value='Keep for later practice';await s.save();assert.equal(s.calls.find(x=>x.name==='staff_question_reserve').args.p_expected_hash,'hash');
 s.w.ST.track='est2';await s.w.render();const reset=s.calls.filter(x=>x.name==='staff_bank_operations').at(-1);assert.equal(reset.args.p_group,null);assert.equal(reset.args.p_cycle,null);s.dom.window.close();
});
test('student sees reference and diagnosis alongside daily destinations and can reach all remaining sections',()=>{
 const dom=new JSDOM('<h1 id="listTitle">SAT</h1><main id="examList"></main>',{runScripts:'outside-only'}),w=dom.window;
 w.ST={track:{id:'sat',name:'SAT'}};w.DASH={view:'daily'};w.esc=esc;w.scrollTo=()=>{};
 w.paintDashboard=()=>{w.document.getElementById('examList').innerHTML='<nav class="student-tabs">'+['daily','formulas','finalsDiagnosis','revision','mistakes','full_exam','overview','history','focus'].map(x=>`<button data-view="${x}">${x}</button>`).join('')+'</nav>';};w.setDashboardView=v=>{w.DASH.view=v;w.paintDashboard();};
 w.eval(fs.readFileSync('web/portal-navigation.js','utf8'));w.eval(source);w.paintDashboard();
 assert.equal([...w.document.querySelectorAll('.student-tabs button')].filter(b=>!b.hidden).length,7);
 assert(!w.document.querySelector('[data-view="formulas"]').hidden);assert(!w.document.querySelector('[data-view="finalsDiagnosis"]').hidden);
 assert.equal(w.document.querySelector('[data-view="daily"]').textContent,'Today');assert(w.document.querySelector('#studentSection option[value="history"]'));
 w.setDashboardView('history');assert(!w.document.querySelector('[data-view="history"]').hidden);assert.equal(w.document.querySelector('#studentSection').value,'history');assert(w.document.querySelector('.portal-skip-link'));dom.window.close();
});
test('deployed management files match source and student history has no new-practice controls',()=>{
 for(const f of ['index.html','admin.html','portal-management.js','portal-management.css','daily-challenge.js'])assert.equal(fs.readFileSync('web/'+f,'utf8'),fs.readFileSync('dist/'+f,'utf8'));
 const html=fs.readFileSync('web/index.html','utf8');assert.match(html,/view:access.practice_open\?'daily':'history'/);assert.match(html,/if\(access.practice_open\)refreshDaily\(\)/);assert.match(html,/can_finish/);
 // Parse every inline script independently: markup injection must never terminate a script.
 for(const name of ['index.html','admin.html']){const dom=new JSDOM(fs.readFileSync('web/'+name,'utf8'));for(const script of dom.window.document.querySelectorAll('script:not([src])'))new(require('node:vm').Script)(script.textContent);dom.window.close();}
});

test('course-plan editor saves every available lesson beyond the former ten-lesson limit',async()=>{
 const lessons=Array.from({length:13},(_,i)=>'Lesson '+(i+1)),s=setup('admin',lessons);s.w.ST.view='coursePlans';await s.w.render();s.w.document.querySelector('[data-plan]').click();await flush();s.w.$('planSelectLessons').click();assert.equal(s.w.document.querySelectorAll('[data-plan-lesson]:checked').length,13);s.w.$('planClearLessons').click();assert.equal(s.w.document.querySelectorAll('[data-plan-lesson]:checked').length,0);s.w.$('planSelectLessons').click();await s.save();assert.deepEqual(JSON.parse(JSON.stringify(s.calls.find(c=>c.name==='staff_save_group_plan').args.p_data.daily_lessons)),lessons);s.dom.window.close();
});
