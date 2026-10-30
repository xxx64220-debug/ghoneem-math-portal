const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const read=f=>fs.readFileSync('web/'+f,'utf8');
function setup(role='admin'){
 const dom=new JSDOM('<dialog id="editor"></dialog>',{runScripts:'outside-only'}),w=dom.window,calls=[];
 w.ST={me:{role,id:'teacher'}};w.$=id=>w.document.getElementById(id);
 w.esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
 const admin=read('admin.html');w.eval(admin.slice(admin.indexOf('const field='),admin.indexOf('function dialog(')).replace(/const (field|area|select|tracks|val|jval)=/g,'window.$1='));
 const gs=[{id:'g1',name:'Sunday',track_id:'est',instructor_id:'teacher'},{id:'g2',name:'Wednesday',track_id:'est',instructor_id:'teacher'},{id:'g3',name:'Other teacher',track_id:'est',instructor_id:'other'},{id:'sat',name:'SAT group',track_id:'sat',instructor_id:'teacher'}];
 const roster=[{user_id:'u',role:'student',tracks:'est, sat',full_name:'Student',email:'one@example.test'},{user_id:'u2',role:'student',tracks:'est',full_name:'Second student',email:'two@example.test'},{user_id:'wrong',role:'student',tracks:'sat',full_name:'Other track'}];
 const members=[{group_id:'g1',user_id:'u'},{group_id:'g3',user_id:'u2'}];
 w.getRows=async table=>({groups:gs,roster,members,group_members:members,assignments:[]})[table]||[];
 w.mutation=async(action,data)=>calls.push({action,data});w.eval(read('exam-assignments.js'));
 let onSave;w.dialog=(title,body,save)=>{w.$('editor').innerHTML='<h2>'+title+'</h2>'+body;onSave=save;};
 w.eval(admin.slice(admin.indexOf('async function assignExam('),admin.indexOf('async function assignmentProgress(')));
 return {dom,w,calls,gs,roster,members,get save(){return onSave;},query:s=>w.document.querySelector(s)};
}
const exam={id:'exam',track_id:'est',title:'EST preparation'};
function realDialog(s){
 const admin=read('admin.html');s.w.render=async()=>{};
 s.w.$('editor').showModal=function(){this.open=true;};
 s.w.$('editor').close=function(){this.open=false;};
 s.w.eval(admin.slice(admin.indexOf('function dialog('),admin.indexOf('async function getRows(')));
}
test('single-exam save locks recipients, dates, cancel and Escape until completion; resubmit is ignored',async()=>{
 const s=setup();realDialog(s);await s.w.assignExam(exam,[]);
 s.query('[data-assignment-group="g1"]').click();s.query('[data-assignment-student="u2"]').click();
 let finish;s.w.mutation=async(action,data)=>{s.calls.push({action,data});if(s.calls.length===1)await new Promise(r=>finish=r);};
 const form=s.w.$('editForm'),event=()=>new s.w.Event('submit',{cancelable:true});
 const pending=form.onsubmit(event());await form.onsubmit(event());assert.equal(s.calls.length,1);
 assert.equal(form.getAttribute('aria-busy'),'true');assert(s.w.$('aopen').disabled);assert(s.query('[data-assignment-student="u2"]').disabled);
 assert(s.w.$('editCancel').disabled);s.w.$('editCancel').click();assert(s.w.$('editor').open);
 const cancel=new s.w.Event('cancel',{cancelable:true});s.w.$('editor').dispatchEvent(cancel);assert(cancel.defaultPrevented);
 finish();await pending;assert.equal(s.calls.length,2);assert.equal(s.w.$('editor').open,false);assert.equal(form.hasAttribute('aria-busy'),false);
 const unlocked=new s.w.Event('cancel',{cancelable:true});s.w.$('editor').dispatchEvent(unlocked);assert.equal(unlocked.defaultPrevented,false);s.dom.window.close();
});
test('failed batch unlocks the same dialog, keeps selected recipients and retries only failures',async()=>{
 const s=setup();realDialog(s);await s.w.assignExam(exam,[]);
 s.query('[data-assignment-group="g1"]').click();s.query('[data-assignment-student="u2"]').click();
 let fail=true;s.w.mutation=async(action,data)=>{s.calls.push({action,data});if(data.user_id==='u2'&&fail)throw new Error('Connection interrupted');};
 const submit=()=>s.w.$('editForm').onsubmit(new s.w.Event('submit',{cancelable:true}));await submit();
 assert(s.w.$('editor').open);assert(!s.w.$('editSave').disabled);assert(!s.w.$('editCancel').disabled);assert(!s.w.$('aopen').disabled);
 assert(s.query('[data-assignment-student="u2"]').checked);assert.match(s.w.$('editError').textContent,/Successful assignments are saved/);
 fail=false;await submit();assert.equal(s.calls.length,3);assert.equal(s.calls.filter(c=>c.data.group_id==='g1').length,1);assert(!s.w.$('editor').open);s.dom.window.close();
});
test('uncertain write and unavailable readback remain retryable; a later uniqueness conflict is reconciled',async()=>{
 const s=setup(),known=[];await s.w.assignExam(exam,known);s.query('[data-assignment-student="u"]').click();
 let unavailable=true;s.w.mutation=async(action,data)=>{s.calls.push({action,data});throw new Error(unavailable?'Response lost':'duplicate key value violates unique constraint');};
 s.w.getRows=async()=>{if(unavailable)throw new Error('Offline');return [{id:'server-id',exam_id:'exam',user_id:'u',group_id:null,close_at:'2026-11-05T00:00:00Z'}];};
 await assert.rejects(()=>s.save(),/Retry to finish/);assert.equal(known.length,0);unavailable=false;await s.save();await s.save();
 assert.equal(s.calls.length,2);assert.equal(known.length,1);assert.equal(known[0].id,'server-id');assert.equal(known[0].close_at,'2026-11-05T00:00:00Z');s.dom.window.close();
});
test('same selected target repeated within a batch is written once; another exam does not suppress it',async()=>{
 const s=setup(),known=[{exam_id:'other-exam',user_id:'u',group_id:null}],target={user_id:'u',group_id:null,name:'Student'};
 await s.w.ExamAssignments.save(exam,[target,target],known,{open_at:null,close_at:null});assert.equal(s.calls.length,1);assert.equal(known.length,2);s.dom.window.close();
});
test('exam form saves several same-track groups with common dates and preserves individual assignments',async()=>{
 const s=setup(),known=[];await s.w.assignExam(exam,known);
 assert.equal(s.query('[data-assignment-group="sat"]'),null);
 assert.equal(s.w.document.querySelectorAll('[data-assignment-student]').length,2);
 s.query('[data-assignment-group="g1"]').click();s.query('[data-assignment-group="g2"]').click();
 assert.match(s.query('[data-assignment-count]').textContent,/2 groups selected/);
 s.w.$('aopen').value='2026-11-01T10:00';s.w.$('aclose').value='2026-11-02T10:00';
 await s.save();assert.equal(s.calls.length,2);assert.deepEqual(s.calls.map(c=>c.data.group_id),['g1','g2']);
 assert(s.calls.every(c=>c.action==='assignment.save'&&c.data.exam_id==='exam'&&c.data.user_id===null&&c.data.open_at===new Date('2026-11-01T10:00').toISOString()));
 await s.save();assert.equal(s.calls.length,2);
 await s.w.assignExam(exam,known);s.query('[data-assignment-student="u"]').click();await s.save();
 assert.equal(s.calls.length,3);assert.equal(s.calls[2].data.user_id,'u');assert.equal(s.calls[2].data.group_id,null);s.dom.window.close();
});
test('empty target and backwards dates do not write; select all and clear work on mobile-friendly checkboxes',async()=>{
 const s=setup();await s.w.assignExam(exam,[]);await assert.rejects(()=>s.save(),/Select at least one/);
 s.query('[data-assignment-all]').click();assert.equal(s.w.document.querySelectorAll('[data-assignment-group]:checked').length,3);
 s.w.$('aopen').value='2026-11-02T10:00';s.w.$('aclose').value='2026-11-01T10:00';await assert.rejects(()=>s.save(),/after opening/);assert.equal(s.calls.length,0);
 s.query('[data-assignment-clear]').click();assert.equal(s.w.document.querySelectorAll('[data-assignment-group]:checked').length,0);s.dom.window.close();
});
test('instructors only see their own groups; group names render as text',()=>{
 const s=setup('instructor');s.gs[0].name='<img src=x onerror=alert(1)>';
 s.roster[0].full_name='<img src=x onerror=alert(1)>';
 const picker=s.w.ExamAssignments.picker({id:'testTargets',track:'est',groups:s.gs,roster:s.roster,members:s.members});s.w.$('editor').innerHTML=picker.html;picker.wire();
 assert.equal(s.w.document.querySelectorAll('[data-assignment-group]').length,2);assert.equal(s.query('img'),null);assert.equal(s.query('[data-assignment-group="g3"]'),null);assert(s.query('[data-assignment-student="u"]'));assert.equal(s.query('[data-assignment-student="u2"]'),null);s.dom.window.close();
});
test('existing group windows and history are preserved while new groups are assigned',async()=>{
 const s=setup(),old={id:'original',exam_id:'exam',group_id:'g1',open_at:'2026-10-01T00:00:00Z',close_at:'2026-10-02T00:00:00Z'},known=[old];await s.w.assignExam(exam,known);
 s.query('[data-assignment-group="g1"]').click();s.query('[data-assignment-group="g2"]').click();await s.save();
 assert.equal(s.calls.length,1);assert.equal(s.calls[0].data.group_id,'g2');assert.equal(known[0],old);assert.equal(known[0].close_at,'2026-10-02T00:00:00Z');s.dom.window.close();
});
test('partial failure retains successes and retry writes only remaining groups',async()=>{
 const s=setup(),known=[];let fail=true;s.w.mutation=async(action,data)=>{s.calls.push({action,data});if(data.group_id==='g2'&&fail)throw new Error('Temporary failure');};
 await s.w.assignExam(exam,known);s.query('[data-assignment-group="g1"]').click();s.query('[data-assignment-group="g2"]').click();
 await assert.rejects(()=>s.save(),/Wednesday: Temporary failure/);assert.equal(known.length,1);fail=false;await s.save();
 assert.deepEqual(s.calls.map(c=>c.data.group_id),['g1','g2','g2']);assert.equal(known.length,2);s.dom.window.close();
});
test('a lost successful response is reconciled with server assignments before retry',async()=>{
 const s=setup(),known=[];s.w.mutation=async()=>{throw new Error('Network failed');};
 s.w.getRows=async table=>table==='assignments'?[{id:'saved',exam_id:'exam',group_id:'g1'}]:table==='groups'?s.gs:s.roster;
 await s.w.assignExam(exam,known);s.query('[data-assignment-group="g1"]').click();await s.save();assert.equal(known[0].id,'saved');s.dom.window.close();
});
test('deployed assets and loader order include the shared assignment control',()=>{
 const served=fs.existsSync('portal-static/admin.html')?'portal-static':'dist';
 for(const f of ['admin.html','exam-assignments.js','exam-assignments.css','group-management.js','admin-bulk.js'])assert.equal(read(f),fs.readFileSync(served+'/'+f,'utf8'));
 const html=read('admin.html');assert(html.indexOf('/exam-assignments.js')<html.indexOf('/group-management.js'));assert(html.indexOf('/exam-assignments.js')<html.indexOf('/admin-bulk.js'));
});
test('Groups entry preselects its group and can add other groups in the same track',async()=>{
 const s=setup();s.w.groups=async()=>{};s.w.getRows=async table=>({exams:[exam,{id:'satExam',track_id:'sat',title:'SAT'}],assignments:[],groups:s.gs})[table]||[];
 s.w.eval(read('group-management.js'));await s.w.GroupManager.assign(s.gs[0]);
 assert(s.query('[data-assignment-group="g1"]').checked);assert.equal(s.w.$('groupAssignExam').querySelectorAll('option').length,1);
 s.query('[data-assignment-group="g2"]').click();await s.save();assert.deepEqual(s.calls.map(c=>c.data.group_id),['g1','g2']);s.dom.window.close();
});
test('several students can receive an exam without any group; existing direct assignments are skipped',async()=>{
 const s=setup(),old={id:'old',exam_id:'exam',user_id:'u',group_id:null,close_at:'2026-10-01T00:00:00Z'},known=[old];await s.w.assignExam(exam,known);
 s.query('[data-assignment-student="u"]').click();s.query('[data-assignment-student="u2"]').click();
 assert.match(s.query('[data-assignment-count]').textContent,/2 students selected · 0 groups selected/);
 await s.save();assert.equal(s.calls.length,1);assert.equal(s.calls[0].data.user_id,'u2');assert.equal(s.calls[0].data.group_id,null);assert.equal(known[0],old);assert.equal(old.close_at,'2026-10-01T00:00:00Z');await s.save();assert.equal(s.calls.length,1);s.dom.window.close();
});
test('students and groups can be selected together with the same window',async()=>{
 const s=setup();await s.w.assignExam(exam,[]);s.query('[data-assignment-group="g1"]').click();s.query('[data-assignment-student="u"]').click();s.query('[data-assignment-student="u2"]').click();s.w.$('aopen').value='2026-11-01T10:00';await s.save();
 assert.equal(s.calls.length,3);assert.equal(s.calls.filter(c=>c.data.user_id).length,2);assert(s.calls.every(c=>c.data.open_at===new Date('2026-11-01T10:00').toISOString()));assert(s.calls.every(c=>Boolean(c.data.group_id)!==Boolean(c.data.user_id)));s.dom.window.close();
});
test('search by name and email selects only shown students and preserves hidden selections',async()=>{
 const s=setup();await s.w.assignExam(exam,[]);const search=s.query('[data-assignment-search]'),input=value=>{search.value=value;search.dispatchEvent(new s.w.Event('input'));};
 input('  TWO@EXAMPLE  ');assert.equal(s.query('[data-assignment-student="u"]').closest('label').hidden,true);s.query('[data-assignment-students-all]').click();
 input('Student');s.query('[data-assignment-student="u"]').click();input('no match');assert.equal(s.query('[data-assignment-empty]').hidden,false);
 assert.match(s.query('[data-assignment-count]').textContent,/2 students selected/);await s.save();assert.deepEqual(s.calls.map(c=>c.data.user_id).sort(),['u','u2']);s.query('[data-assignment-students-clear]').click();await assert.rejects(()=>s.save(),/Select at least one/);s.dom.window.close();
});
test('student failure can be retried without resaving successful students',async()=>{
 const s=setup(),known=[];let fail=true;s.w.mutation=async(action,data)=>{s.calls.push({action,data});if(data.user_id==='u2'&&fail)throw new Error('Temporary failure');};await s.w.assignExam(exam,known);s.query('[data-assignment-students-all]').click();
 await assert.rejects(()=>s.save(),/Second student: Temporary failure/);assert.equal(known.length,1);fail=false;await s.save();assert.equal(s.calls.length,3);assert.equal(s.calls.filter(c=>c.data.user_id==='u').length,1);assert.equal(known.length,2);s.dom.window.close();
});
test('student picker isolates every course, excludes suspended accounts and staff, and deduplicates roster rows',()=>{
 const s=setup();s.roster.push({...s.roster[0]},{user_id:'paused',role:'student',status:'suspended',tracks:'est',full_name:'Suspended'},{user_id:'staff',role:'instructor',tracks:'est',full_name:'Teacher'},{user_id:'est2',role:'student',tracks:'est2',full_name:'EST II'},{user_id:'english',role:'student',tracks:'est_eng',full_name:'English'});
 for(const [track,ids] of [['sat',['u','wrong']],['est',['u','u2']],['est2',['est2']],['est_eng',['english']]]){const p=s.w.ExamAssignments.picker({id:'testTargets',track,groups:s.gs,roster:s.roster});s.w.$('editor').innerHTML=p.html;p.wire();assert.deepEqual([...s.w.document.querySelectorAll('[data-assignment-student]')].map(b=>b.dataset.assignmentStudent).sort(),ids.sort());}s.dom.window.close();
});
test('instructors require owned-group membership in the exam track for direct targets',()=>{
 const s=setup('instructor');s.members.push({group_id:'sat',user_id:'u2'});const p=s.w.ExamAssignments.picker({id:'testTargets',track:'est',groups:s.gs,roster:s.roster,members:s.members});s.w.$('editor').innerHTML=p.html;p.wire();assert(s.query('[data-assignment-student="u"]'));assert.equal(s.query('[data-assignment-student="u2"]'),null);s.dom.window.close();
});
test('Groups entry can clear its preselected group and assign only selected students',async()=>{
 const s=setup();s.w.groups=async()=>{};s.w.getRows=async table=>({exams:[exam],assignments:[],groups:s.gs,roster:s.roster,group_members:s.members})[table]||[];s.w.eval(read('group-management.js'));await s.w.GroupManager.assign(s.gs[0]);
 s.query('[data-assignment-clear]').click();s.query('[data-assignment-student="u"]').click();s.query('[data-assignment-student="u2"]').click();await s.save();assert.equal(s.calls.length,2);assert(s.calls.every(c=>c.data.group_id===null&&c.data.user_id));s.dom.window.close();
});
test('combined review shows each eligible student once and keeps selected sources visible during search',async()=>{
 const s=setup();s.members.push({group_id:'g2',user_id:'u'},{group_id:'g2',user_id:'u2'},{group_id:'g2',user_id:'u'});
 await s.w.assignExam(exam,[]);s.query('[data-assignment-group="g1"]').click();s.query('[data-assignment-group="g2"]').click();s.query('[data-assignment-student="u"]').click();
 const review=s.query('[data-assignment-review]');assert.match(review.textContent,/2 unique students/);assert.match(review.textContent,/1 reached by more than one selection/);
 assert.equal(review.querySelectorAll('li').length,2);assert.match(review.querySelector('li').textContent,/Sunday · Wednesday · Individual assignment/);
 const search=s.query('[data-assignment-search]');search.value='not a student';search.dispatchEvent(new s.w.Event('input'));assert.equal(review.querySelectorAll('li').length,2);
 await s.save();await s.save();assert.equal(s.calls.length,3,'one record per target, not per membership or retry');s.dom.window.close();
});
test('window summary ignores expired and future assignments when access is currently open',()=>{
 const s=setup(),now=Date.parse('2026-11-01T10:00:00Z'),summary=as=>s.w.ExamAssignments.windowSummary(as,now);
 const expired={close_at:'2026-10-01T10:00:00Z'},future={open_at:'2026-11-03T10:00:00Z',close_at:'2026-11-04T10:00:00Z'},active={open_at:'2026-11-01T09:00:00Z',close_at:'2026-11-01T11:00:00Z'};
 assert.equal(summary([expired,future,active]).close,active.close_at);assert.equal(summary([expired,future,active]).state,'Open');
 assert.equal(summary([expired,future,{}]).close,null);assert.equal(summary([expired,future,{}]).state,'Open');
 assert.equal(summary([expired,future]).state,'Upcoming');assert.equal(summary([expired,future]).open,future.open_at);assert.equal(summary([expired]).state,'Closed');
 assert.equal(summary([{open_at:'2026-11-01T10:00:00Z',close_at:'2026-11-01T11:00:00Z'}]).state,'Open');assert.equal(summary([{close_at:'2026-11-01T10:00:00Z'}]).state,'Open');
 assert.equal(summary([{},active]).close,active.close_at,'matches server earliest active close');s.dom.window.close();
});
test('actual progress form deduplicates overlapping groups and direct assignments with the active deadline',async()=>{
 const s=setup(),now=Date.now(),close=new Date(now+86400000).toISOString(),expired=new Date(now-86400000).toISOString();
 s.w.wrapTable=x=>x;s.w.sortText=(a,b)=>a.localeCompare(b);s.members.push({group_id:'g2',user_id:'u'});
 s.w.getRows=async table=>({roster:s.roster,group_members:s.members,attempts:[{user_id:'u',exam_id:'exam',status:'graded',started_at:new Date(now-2000).toISOString()},{user_id:'u',exam_id:'exam',status:'in_progress',started_at:new Date(now-1000).toISOString()}]})[table]||[];
 s.w.$('editor').showModal=()=>{};
 const admin=read('admin.html');s.w.eval(admin.slice(admin.indexOf('async function assignmentProgress('),admin.indexOf('async function students(){',admin.indexOf('async function assignmentProgress('))));
 await s.w.assignmentProgress(exam,[{exam_id:'exam',group_id:'g1',close_at:expired},{exam_id:'exam',group_id:'g2',close_at:close},{exam_id:'exam',user_id:'u',open_at:new Date(now+2*86400000).toISOString()}]);
 assert.equal(s.w.document.querySelectorAll('tbody tr').length,1);const text=s.w.$('editor').textContent;
 assert.match(text,/In progress/);assert.match(text,/Open/);assert(text.includes(new s.w.Date(close).toLocaleString()));assert(!text.includes(new s.w.Date(expired).toLocaleString()));s.dom.window.close();
});
