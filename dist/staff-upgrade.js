// Staff authoring uses server-authorized transactions; reads remain under RLS.
async function mutation(action,data){const r=await fn('staff-console',{body:{action,data}});if(!r.ok)throw new Error(r.json.error||'Could not save');return r.json;}
const field=(id,label,value='',type='text')=>`<div class="field"><label for="${id}">${label}</label><input id="${id}" type="${type}" value="${esc(value)}"></div>`;
const area=(id,label,value='')=>`<div class="field"><label for="${id}">${label}</label><textarea id="${id}" rows="4">${esc(value)}</textarea></div>`;
const select=(id,label,options,value='')=>`<div class="field"><label for="${id}">${label}</label><select id="${id}">${options.map(([v,t])=>`<option value="${esc(v)}" ${String(v)===String(value)?'selected':''}>${esc(t)}</option>`).join('')}</select></div>`;
const tracks=()=>ST.tracks.map(t=>[t.id,t.name]);
const val=id=>$(id).value.trim();
const jval=id=>val(id)?JSON.parse(val(id)):null;
function dialog(title,body,onSave,button='Save'){
 $('editor').innerHTML=`<form id="editForm"><h2>${title}</h2>${body}<div id="editError" class="err" role="alert"></div><div class="actions"><button class="btn" id="editSave">${button}</button><button class="btn-sm" type="button" id="editCancel">Cancel</button></div></form>`;
 $('editCancel').onclick=()=>$('editor').close();
 $('editForm').onsubmit=async e=>{e.preventDefault();$('editSave').disabled=true;$('editError').textContent='';try{await onSave();$('editor').close();await render();}catch(e){$('editError').textContent=e.message;}finally{$('editSave').disabled=false;}};
 $('editor').showModal();
}
async function getRows(table,track=false){let b=q(table);if(track&&ST.track)b=b.eq('track_id',ST.track);const {data}=await b;return data||[];}
const wrapTable=html=>`<div class="table-wrap">${html}</div>`;
async function bank(){
 const rows=await getRows('questions',true);
 $('view').innerHTML=`<div class="head"><h2>Question bank</h2><span class="hint">${rows.length} questions</span><div class="sp"></div><button class="btn-sm" id="importQ">Import JSON</button><button class="btn" id="newQ">Add question</button></div><p class="hint" style="margin-bottom:16px">Original diagrams and tables stay attached to each question. Questions used in published exams are protected from editing.</p><input id="qSearch" placeholder="Search a topic or question" aria-label="Search questions" style="margin-bottom:16px"><div id="bankTable"></div>`;
 const paint=()=>{$('bankTable').innerHTML=wrapTable(`<table><thead><tr><th>Track</th><th>Topic</th><th>Question</th><th>Type</th><th></th></tr></thead><tbody>${rows.filter(x=>(x.topic+' '+x.stem).toLowerCase().includes(val('qSearch').toLowerCase())).map(x=>`<tr><td>${esc(x.track_id.toUpperCase())}</td><td>${esc(x.topic)}</td><td>${esc(x.stem.slice(0,150))}</td><td>${esc(x.type)}</td><td><button class="btn-sm" data-edit-q="${x.id}">Edit</button></td></tr>`).join('')}</tbody></table>`);document.querySelectorAll('[data-edit-q]').forEach(b=>b.onclick=()=>editQuestion(rows.find(x=>x.id===b.dataset.editQ)));};
 $('qSearch').oninput=paint;paint();$('newQ').onclick=()=>editQuestion();$('importQ').onclick=importQuestions;
}
async function editQuestion(x={}){
 let key={};if(x.id){const {data,error}=await sb.from('question_keys').select('*').eq('question_id',x.id).single();if(error){alert(error.message);return;}key=data;}
 dialog(x.id?'Edit question':'Add question',select('qt','Track',tracks(),x.track_id||ST.track)+field('qtopic','Topic',x.topic)+select('qtype','Answer type',[['mcq','Multiple choice'],['grid_in','Student response']],x.type)+select('qd','Difficulty',[['easy','Easy'],['medium','Medium'],['hard','Hard']],x.difficulty||'medium')+area('qstem','Question',x.stem)+area('qchoices','Choices — one per line, in display order',(x.choices||[]).map(c=>c.text).join('\n'))+field('qcorrect','Correct answer — choice letter, or accepted numeric answers separated by ;',key.correct?.void?'Excluded from scoring':Array.isArray(key.correct)?key.correct.join('; '):key.correct)+area('qexplain','Worked explanation',key.explanation)+area('qassets','Diagrams and tables (assets JSON; optional)',JSON.stringify(x.assets||{})),async()=>{
 const type=val('qtype');const choices=val('qchoices').split('\n').filter(Boolean).map((text,i)=>({key:String.fromCharCode(65+i),text}));
 await mutation('question.save',{id:x.id,track_id:val('qt'),topic:val('qtopic'),type,difficulty:val('qd'),stem:val('qstem'),choices:type==='mcq'?choices:[],correct:type==='mcq'?val('qcorrect').toUpperCase():val('qcorrect').split(';').map(x=>x.trim()),explanation:val('qexplain'),assets:jval('qassets')||{}});
 });if(x.id)$('qt').disabled=true;
}
function importQuestions(){
 dialog('Import a question bank',select('it','Track',tracks(),ST.track)+`<p class="hint">Upload a JSON array with up to 500 questions. Each needs stem, type, correct, and choices for multiple choice. Optional: topic, difficulty, explanation, assets. All questions are checked before any are imported.</p><a href="/question-bank-example.json" download>Download an example</a><div class="field" style="margin-top:16px"><label for="ifile">Question-bank file</label><input id="ifile" type="file" accept=".json,application/json" required></div>`,async()=>{
 const file=$('ifile').files[0];if(!file)throw new Error('Choose a file.');if(file.size>5000000)throw new Error('File must be below 5 MB.');const body=JSON.parse(await file.text());await mutation('question.import',{track_id:val('it'),questions:Array.isArray(body)?body:body.questions});
 },'Validate & import');
}
async function exams(){
 const rows=await getRows('exams',true),assignments=await getRows('assignments');
 $('view').innerHTML=`<div class="head"><h2>Exams & assignments</h2><div class="sp"></div><button class="btn" id="newExam">Create exam</button></div>${wrapTable(`<table><thead><tr><th>Track</th><th>Exam</th><th>Category</th><th>Questions</th><th>Minutes</th><th>Assignments</th><th>Status</th><th>Actions</th></tr></thead><tbody>${rows.map(x=>`<tr><td>${esc(x.track_id.toUpperCase())}</td><td>${esc(x.title)}</td><td><select aria-label="Category for ${esc(x.title)}" data-classify="${x.id}">${[['lesson_exam','Lesson exam'],['quiz','Quiz'],['full_exam','Full exam']].map(([v,t])=>`<option value="${v}" ${x.assessment_type===v?'selected':''}>${t}</option>`).join('')}</select></td><td>${x.question_ids.length}</td><td>${Math.round(x.duration_seconds/60)}</td><td>${assignments.filter(a=>a.exam_id===x.id).length}</td><td>${x.is_published?'Published':'Draft'}</td><td><button class="btn-sm" data-ex-edit="${x.id}">Edit</button> <button class="btn-sm" data-ex-assign="${x.id}">Assign</button> <button class="btn-sm" data-ex-pub="${x.id}">${x.is_published?'Unpublish':'Publish'}</button> <button class="btn-sm" data-ex-release="${x.id}">Release review</button></td></tr>`).join('')}</tbody></table>`)}<p class="hint" style="margin-top:16px">Publish an exam and assign it to a student or group. A closing time delays worked answers until the window ends. EST is calculator-allowed throughout. Full papers use raw marks until an exact score conversion is provided.</p>`;
 $('newExam').onclick=()=>editExam();
 document.querySelectorAll('[data-classify]').forEach(b=>b.onchange=async()=>{b.disabled=true;try{await mutation('exam.classify',{id:b.dataset.classify,assessment_type:b.value});}catch(e){alert(e.message);await render();}finally{b.disabled=false;}});
 document.querySelectorAll('[data-ex-edit]').forEach(b=>b.onclick=()=>editExam(rows.find(x=>x.id===b.dataset.exEdit)));
 document.querySelectorAll('[data-ex-assign]').forEach(b=>b.onclick=()=>assignExam(rows.find(x=>x.id===b.dataset.exAssign),assignments));
 document.querySelectorAll('[data-ex-pub]').forEach(b=>b.onclick=async()=>{try{const x=rows.find(x=>x.id===b.dataset.exPub);await mutation('exam.save',{id:x.id,is_published:!x.is_published});await render();}catch(e){alert(e.message);}});
 document.querySelectorAll('[data-ex-release]').forEach(b=>b.onclick=async()=>{if(!confirm('Release worked answers for completed attempts?'))return;try{await mutation('review.release',{exam_id:b.dataset.exRelease});await render();}catch(e){alert(e.message);}});
}
async function editExam(x={}){
 const questions=await getRows('questions');
 dialog(x.id?'Edit exam':'Create exam',select('et','Track',tracks(),x.track_id||ST.track)+field('etitle','Exam title',x.title)+field('emins','Duration in minutes',x.duration_seconds?x.duration_seconds/60:25,'number')+select('ereview','Review policy',[['full_review','Full answers after submission or window close'],['score_only','Score only'],['instructor_release','Release answers manually']],x.review_policy)+select('etype','Assessment category',[['lesson_exam','Lesson exam'],['quiz','Quiz'],['full_exam','Full exam']],x.assessment_type||(x.is_full_length?'full_exam':'lesson_exam'))+area('emap','Exact raw-to-scaled conversion (optional JSON)',x.scoring_map?JSON.stringify(x.scoring_map):'')+`<div class="field"><label for="efilter">Find questions</label><input id="efilter" placeholder="Topic or question text"></div><p id="eselected" class="hint"></p><div class="question-select" id="eqs"></div>`,async()=>{
 await mutation('exam.save',{id:x.id,track_id:val('et'),title:val('etitle'),duration_seconds:Math.round(Number(val('emins'))*60),question_ids:[...selected],is_full_length:val('etype')==='full_exam',assessment_type:val('etype'),scoring_map:jval('emap'),review_policy:val('ereview'),is_published:x.is_published||false});
 });
 let selected=new Set(x.question_ids||[]);
 const paint=()=>{$('eqs').innerHTML=questions.filter(q=>q.track_id===val('et')&&(q.topic+' '+q.stem).toLowerCase().includes(val('efilter').toLowerCase())).map(q=>`<label class="check"><input type="checkbox" data-qid="${q.id}" ${selected.has(q.id)?'checked':''}><span><b>${esc(q.topic)}</b> · ${esc(q.stem.slice(0,180))}</span></label>`).join('');$('eselected').textContent=selected.size+' questions selected';$('eqs').querySelectorAll('input').forEach(b=>b.onchange=()=>{b.checked?selected.add(b.dataset.qid):selected.delete(b.dataset.qid);$('eselected').textContent=selected.size+' questions selected';});};
 $('et').onchange=()=>{selected.clear();paint();};$('efilter').oninput=paint;if(x.id)$('et').disabled=true;paint();
}
async function assignExam(ex,assignments){
 const [roster,gs]=await Promise.all([getRows('roster'),getRows('groups')]);
 const options=[...gs.filter(g=>g.track_id===ex.track_id).map(g=>['g:'+g.id,'Group: '+g.name]),...roster.filter(r=>r.role==='student'&&r.tracks.split(', ').includes(ex.track_id)).map(r=>['u:'+r.user_id,'Student: '+(r.full_name||r.email)])];
 if(!options.length){alert('Enrol a student or create a group in this track first.');return;}
 const existing=assignments.filter(a=>a.exam_id===ex.id);
 dialog('Assign '+esc(ex.title),select('atarget','Assign to',options)+field('aopen','Opens at (your local time)','','datetime-local')+field('aclose','Closes at (your local time; optional)','','datetime-local')+`<p class="hint">Leave times blank for a self-paced assignment. ${existing.length} assignment(s) already exist for this exam.</p>`,async()=>{
 const [type,id]=val('atarget').split(':');await mutation('assignment.save',{exam_id:ex.id,user_id:type==='u'?id:null,group_id:type==='g'?id:null,open_at:val('aopen')?new Date(val('aopen')).toISOString():null,close_at:val('aclose')?new Date(val('aclose')).toISOString():null});
 },'Assign exam');
}
async function students(){
 const all=await getRows('roster'),rows=ST.track?all.filter(x=>x.tracks.split(', ').includes(ST.track)):all;
 $('view').innerHTML=`<div class="head"><h2>Accounts</h2><div class="sp"></div>${ST.me.role==='admin'?'<button class="btn" id="addAccount">Create account</button>':''}</div>${wrapTable(`<table><thead><tr><th>Name</th><th>Sign-in email</th><th>Role</th><th>Tracks</th><th>Status</th><th></th></tr></thead><tbody>${rows.map(x=>`<tr><td>${esc(x.full_name||'Unnamed student')}</td><td>${esc(x.email)}</td><td>${esc(x.role)}</td><td>${esc(x.tracks)}</td><td>${esc(x.status)}</td><td>${ST.me.role==='admin'?`<button class="btn-sm" data-user="${x.user_id}">Manage</button>`:''}</td></tr>`).join('')}</tbody></table>`)}`;
 if($('addAccount'))$('addAccount').onclick=()=>dialog('Create account',field('uname','Username or email')+field('ufull','Full name')+field('upass','Initial password (at least 8 characters)','','password')+select('urole','Role',[['student','Student'],['instructor','Instructor'],['admin','Admin']])+`<p class="hint">Student enrollment</p>`+ST.tracks.map(t=>`<label class="check"><input type="checkbox" data-enroll="${t.id}">${esc(t.name)}</label>`).join(''),async()=>{
 const u=val('uname'),selected=[...document.querySelectorAll('[data-enroll]:checked')].map(b=>b.dataset.enroll);const res=await fn('admin-users',{body:{username:u.includes('@')?'':u,email:u.includes('@')?u:undefined,full_name:val('ufull'),password:$('upass').value,role:val('urole'),tracks:val('urole')==='student'?selected:[]}});if(!res.ok)throw new Error(res.json.error);if(val('urole')==='instructor'&&selected.length)await mutation('instructor.tracks',{id:res.json.user_id,tracks:selected});
 },'Create account');
 document.querySelectorAll('[data-user]').forEach(b=>b.onclick=()=>manageUser(rows.find(x=>x.user_id===b.dataset.user)));
}
async function manageUser(u){
 dialog('Manage account',field('mname','Full name',u.full_name)+select('mrole','Role',[['student','Student'],['instructor','Instructor'],['admin','Admin']],u.role)+select('mstatus','Status',[['active','Active'],['suspended','Suspended']],u.status)+`<p class="hint">Track access</p>`+ST.tracks.map(t=>`<label class="check"><input type="checkbox" data-track="${t.id}" ${u.tracks.split(', ').includes(t.id)?'checked':''}>${esc(t.name)}</label>`).join(''),async()=>{
 await mutation('user.update',{id:u.user_id,full_name:val('mname'),role:val('mrole'),status:val('mstatus')});
 const sels=[...document.querySelectorAll('[data-track]')];
 if(val('mrole')==='instructor')await mutation('instructor.tracks',{id:u.user_id,tracks:sels.filter(b=>b.checked).map(b=>b.dataset.track)});
 else if(val('mrole')==='student')for(const b of sels)await mutation('enrollment.save',{user_id:u.user_id,track_id:b.dataset.track,status:b.checked?'active':'paused'});
 });
 if(u.role==='instructor'){const {data}=await q('instructor_tracks').eq('user_id',u.user_id);document.querySelectorAll('[data-track]').forEach(b=>b.checked=(data||[]).some(t=>t.track_id===b.dataset.track));}
}
async function groups(){
 const rows=await getRows('groups',true),roster=await getRows('roster'),members=await getRows('group_members');
 $('view').innerHTML=`<div class="head"><h2>Groups</h2><div class="sp"></div><button class="btn" id="newGroup">Create group</button></div>${wrapTable(`<table><tr><th>Group</th><th>Track</th><th>Members</th><th></th></tr>${rows.map(g=>`<tr><td>${esc(g.name)}</td><td>${esc(g.track_id)}</td><td>${members.filter(m=>m.group_id===g.id).length}</td><td><button class="btn-sm" data-group="${g.id}">Manage</button></td></tr>`).join('')}</table>`)}`;
 const edit=(g={})=>{dialog(g.id?'Manage group':'Create group',field('gname','Group name',g.name)+select('gtrack','Track',tracks(),g.track_id||ST.track)+(ST.me.role==='admin'?select('ginstructor','Instructor',[['','Unassigned'],...roster.filter(r=>r.role==='instructor').map(r=>[r.user_id,r.full_name])],g.instructor_id):'')+`<div id="gmembers"></div>`,async()=>{await mutation('group.save',{id:g.id,name:val('gname'),track_id:val('gtrack'),instructor_id:$('ginstructor')?val('ginstructor'):ST.me.id,user_ids:[...document.querySelectorAll('[data-member]:checked')].map(b=>b.dataset.member)});});const paint=()=>{$('gmembers').innerHTML=roster.filter(r=>r.role==='student'&&r.tracks.split(', ').includes(val('gtrack'))).map(r=>`<label class="check"><input type="checkbox" data-member="${r.user_id}" ${members.some(m=>m.group_id===g.id&&m.user_id===r.user_id)?'checked':''}>${esc(r.full_name||r.email)}</label>`).join('');};$('gtrack').onchange=paint;if(g.id)$('gtrack').disabled=true;paint();};
 $('newGroup').onclick=()=>edit();document.querySelectorAll('[data-group]').forEach(b=>b.onclick=()=>edit(rows.find(g=>g.id===b.dataset.group)));
}
async function devices(){
 if(ST.me.role!=='admin'){$('view').innerHTML='<div class="empty">Device management is available to administrators.</div>';return;}
 const [rows,users]=await Promise.all([getRows('device_sessions'),getRows('roster')]);
 $('view').innerHTML=`<div class="head"><h2>Devices</h2></div><p class="hint" style="margin-bottom:16px">Up to three active sign-ins per account. Revocation blocks that session from exams and answer saves.</p>${wrapTable(`<table><tr><th>Account</th><th>Device</th><th>Last seen</th><th></th></tr>${rows.map(d=>`<tr><td>${esc(users.find(u=>u.user_id===d.user_id)?.email||d.user_id)}</td><td>${esc(d.user_agent.slice(0,110))}</td><td>${esc(new Date(d.last_seen).toLocaleString())}</td><td>${d.revoked_at?'Revoked':`<button class="btn-sm" data-revoke="${d.id}">Revoke</button>`}</td></tr>`).join('')}</table>`)}`;
 document.querySelectorAll('[data-revoke]').forEach(b=>b.onclick=async()=>{if(!confirm('Revoke access from this device?'))return;try{await mutation('device.revoke',{id:b.dataset.revoke});await render();}catch(e){alert(e.message);}});
}
async function audit(){
 if(ST.me.role!=='admin'){$('view').innerHTML='<div class="empty">Audit logs are available to administrators.</div>';return;}
 const {data:rows}=await q('audit_log').order('at',{ascending:false}).limit(300);
 $('view').innerHTML=`<div class="head"><h2>Audit log</h2><div class="sp"></div><button class="btn-sm" id="auditCsv">Export CSV</button></div>${wrapTable(`<table><tr><th>Time</th><th>Action</th><th>Actor</th><th>Target</th></tr>${rows.map(a=>`<tr><td>${esc(new Date(a.at).toLocaleString())}</td><td>${esc(a.action)}</td><td class="hint">${esc(a.actor_id)}</td><td class="hint">${esc(a.target_id)}</td></tr>`).join('')}</table>`)}`;$('auditCsv').onclick=()=>csv(rows,'audit-log');
}
