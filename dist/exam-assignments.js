// One existing assignment per exam/target; group membership and access stay server-authorized.
(function(){
 'use strict';
 // Targets remain independent so future group membership changes still work.
 // Effective recipients and progress are always one row per student/exam.
 function recipients(targets,roster,members){
  const people=new Map(roster.map(r=>[r.user_id,r])),rows=new Map();
  for(const target of targets){
   const ids=target.user_id?[target.user_id]:members.filter(m=>m.group_id===target.group_id).map(m=>m.user_id);
   for(const id of new Set(ids)){
    if(!people.has(id))continue;
    if(!rows.has(id))rows.set(id,{person:people.get(id),targets:[]});
    rows.get(id).targets.push(target);
   }
  }
  return [...rows.values()];
 }
 function windowSummary(assignments,now=Date.now()){
  const start=a=>a.open_at?new Date(a.open_at).getTime():-Infinity;
  const end=a=>a.close_at?new Date(a.close_at).getTime():Infinity;
  // Match student_assignment_for: only open windows participate, then the
  // earliest close wins. A future/expired row cannot mask current access.
  const active=assignments.filter(a=>start(a)<=now&&end(a)>=now).sort((a,b)=>end(a)-end(b));
  if(active.length)return {state:'Open',close:active[0].close_at||null,open:active[0].open_at||null};
  const upcoming=assignments.filter(a=>start(a)>now&&end(a)>=start(a)).sort((a,b)=>start(a)-start(b)||end(a)-end(b));
  if(upcoming.length)return {state:'Upcoming',close:upcoming[0].close_at||null,open:upcoming[0].open_at};
  const closed=assignments.filter(a=>end(a)<now).sort((a,b)=>end(b)-end(a));
  return {state:'Closed',close:closed[0]?.close_at||null,open:null};
 }
 function picker({id,track,groups,roster=[],members=[],selected=[]}){
  const gs=groups.filter(g=>g.track_id===track&&(ST.me.role==='admin'||g.instructor_id===ST.me.id));
  const ownedMembers=new Set(members.filter(m=>gs.some(g=>g.id===m.group_id)).map(m=>m.user_id));
  const students=[...new Map(roster.filter(r=>r.role==='student'&&r.status!=='suspended'&&(r.tracks||'').split(/\s*,\s*/).includes(track)&&(ST.me.role==='admin'||ownedMembers.has(r.user_id))).map(r=>[r.user_id,r])).values()].sort((a,b)=>(a.full_name||a.email||'').localeCompare(b.full_name||b.email||''));
  const targets=[...gs.map(g=>({key:'g:'+g.id,group_id:g.id,user_id:null,name:g.name})),...students.map(r=>({key:'u:'+r.user_id,group_id:null,user_id:r.user_id,name:r.full_name||r.email}))];
  const html=`<section id="${id}" class="assignment-targets"><p class="hint">Choose students, groups, or both. Leave groups clear to assign only to specific students.</p><fieldset><legend>Individual students · choose one or more</legend><p class="hint">Students with active subscriptions in this exam’s track${ST.me.role==='admin'?'':' and your teaching groups'} are shown. Course access is checked when saving.</p><div class="field"><label for="${id}Search">Find a student by name or email</label><input id="${id}Search" type="search" data-assignment-search autocomplete="off"></div><div class="actions"><button type="button" class="btn-sm" data-assignment-students-all>Select shown students</button><button type="button" class="btn-sm" data-assignment-students-clear>Clear students</button></div><div class="assignment-student-list">${students.map(r=>`<label class="check" data-assignment-person><input type="checkbox" data-assignment-student="${esc(r.user_id)}"><span>${esc(r.full_name||r.email)}${r.email&&r.full_name?`<small>${esc(r.email)}</small>`:''}</span></label>`).join('')}</div><p class="hint" data-assignment-empty ${students.length?'hidden':''}>${students.length?'No students match your search.':'No eligible students. Check their subscription and account status'+(ST.me.role==='admin'?'.':' and membership in your teaching groups.')}</p></fieldset><fieldset><legend>Groups · choose one or more</legend><p class="hint">Only groups in this exam’s track are shown.</p><div class="actions"><button type="button" class="btn-sm" data-assignment-all>Select all groups</button><button type="button" class="btn-sm" data-assignment-clear>Clear groups</button></div><div class="assignment-group-list">${gs.map(g=>`<label class="check"><input type="checkbox" data-assignment-group="${esc(g.id)}" ${selected.includes(g.id)?'checked':''}><span>${esc(g.name)}</span></label>`).join('')||'<p class="hint">No eligible groups in this track.</p>'}</div></fieldset><p data-assignment-count class="hint" role="status" aria-live="polite"></p><details class="assignment-review" open><summary>Review combined recipients</summary><div data-assignment-review></div><p class="hint">Students in several selected groups appear once here and once in exam progress. Group membership and course access are checked again by the server. Group assignments follow future membership changes.</p></details></section>`;
  const root=()=>$(id);
  function chosen(){
   const keys=[...root().querySelectorAll('[data-assignment-group]:checked')].map(b=>'g:'+b.dataset.assignmentGroup);
   root().querySelectorAll('[data-assignment-student]:checked').forEach(b=>keys.push('u:'+b.dataset.assignmentStudent));
   const result=targets.filter(t=>keys.includes(t.key));
   if(!result.length)throw new Error('Select at least one student or group.');
   return result;
  }
  function wire(){
   const box=root(),count=()=>{
    const n=box.querySelectorAll('[data-assignment-group]:checked').length,s=box.querySelectorAll('[data-assignment-student]:checked').length;
    box.querySelector('[data-assignment-count]').textContent=s+' '+(s===1?'student':'students')+' selected · '+n+' '+(n===1?'group':'groups')+' selected';
    const chosenTargets=n+s?chosen():[],rows=recipients(chosenTargets,students,members);
    const overlap=rows.filter(r=>r.targets.length>1).length;
    box.querySelector('[data-assignment-review]').innerHTML=chosenTargets.length?`<p>${rows.length} unique ${rows.length===1?'student':'students'} currently eligible${overlap?` · ${overlap} reached by more than one selection`:''}</p><p class="hint">Selected targets: ${chosenTargets.map(t=>esc(t.name)).join(' · ')}</p><ul class="assignment-recipient-list">${rows.map(r=>`<li><b>${esc(r.person.full_name||r.person.email)}</b><small>${r.targets.map(t=>t.user_id?'Individual assignment':esc(t.name)).join(' · ')}</small></li>`).join('')}</ul>`:'<p class="hint">Select students or groups to review recipients.</p>';
   };
   box.querySelector('[data-assignment-all]').onclick=()=>{box.querySelectorAll('[data-assignment-group]').forEach(b=>b.checked=true);count();};
   box.querySelector('[data-assignment-clear]').onclick=()=>{box.querySelectorAll('[data-assignment-group]').forEach(b=>b.checked=false);count();};
   box.querySelectorAll('[data-assignment-group],[data-assignment-student]').forEach(b=>b.onchange=count);
   box.querySelector('[data-assignment-search]').oninput=e=>{const query=e.target.value.trim().toLocaleLowerCase();let shown=0;box.querySelectorAll('[data-assignment-person]').forEach(row=>{row.hidden=!row.textContent.toLocaleLowerCase().includes(query);if(!row.hidden)shown++;});box.querySelector('[data-assignment-empty]').hidden=shown>0;};
   box.querySelector('[data-assignment-students-all]').onclick=()=>{box.querySelectorAll('[data-assignment-person]').forEach(row=>{if(!row.hidden)row.querySelector('input').checked=true;});count();};
   box.querySelector('[data-assignment-students-clear]').onclick=()=>{box.querySelectorAll('[data-assignment-student]').forEach(b=>b.checked=false);count();};count();
   // Bulk assignment owns its own lifecycle. Protect the single-exam and
   // group-entry dialogs too: their generic editor otherwise allows closing
   // or changing recipients while an earlier save is still in flight.
   const form=box.closest('form'),editor=box.closest('dialog');
   if(form?.id==='editForm'&&form.onsubmit){
    const submit=form.onsubmit,status=document.createElement('p');let busy=false;
    status.className='hint';status.setAttribute('role','status');status.setAttribute('aria-live','polite');box.append(status);
    form.onsubmit=async e=>{
     e.preventDefault();if(busy)return;busy=true;
     const controls=[...form.querySelectorAll('input,select,textarea,button')].map(el=>[el,el.disabled]);
     const preventCancel=e=>e.preventDefault();editor?.addEventListener('cancel',preventCancel);
     controls.forEach(([el])=>el.disabled=true);form.setAttribute('aria-busy','true');status.textContent='Saving assignments…';
     try{await submit.call(form,e);}
     finally{busy=false;controls.forEach(([el,disabled])=>el.disabled=disabled);form.removeAttribute('aria-busy');editor?.removeEventListener('cancel',preventCancel);status.textContent='';}
    };
   }
  }
  return {html,chosen,wire};
 }
 function dates(openId,closeId){
  const parse=id=>{const raw=val(id);if(!raw)return null;const d=new Date(raw);if(!Number.isFinite(d.getTime()))throw new Error('Enter a valid assignment date.');return d.toISOString();};
  const open_at=parse(openId),close_at=parse(closeId);
  if(open_at&&close_at&&close_at<=open_at)throw new Error('Closing time must be after opening time.');
  return {open_at,close_at};
 }
 async function save(exam,targets,known,times){
  let saved=0;const errors=[];
  const matches=(a,t)=>a.exam_id===exam.id&&(t.group_id?a.group_id===t.group_id:a.user_id===t.user_id);
  for(const target of targets){
   if(known.some(a=>matches(a,target)))continue;
   const data={exam_id:exam.id,group_id:target.group_id,user_id:target.user_id,...times};
   try{await mutation('assignment.save',data);known.push(data);saved++;}
   catch(e){
    // A response may be lost after a successful save. Read back before retrying.
    let live;try{live=await getRows('assignments',false,'*','','exam_id',exam.id);}catch(_){}
    const existing=live?.find(a=>matches(a,target));
    if(existing){known.push(existing);continue;}
    errors.push(target.name+': '+(e.message||'Could not save'));
   }
  }
  if(errors.length)throw new Error(errors.join('\n')+'\nSuccessful assignments are saved. Retry to finish the remaining students or groups.');
  return saved?undefined:'skipped';
 }
 window.ExamAssignments={picker,dates,save,recipients,windowSummary};
})();
