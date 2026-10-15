// Shared selection UI; writes use the same server-authorized actions as single-row edits.
(function(){
 'use strict';
 let scope='',selected=new Map(),busy=false,preparing=false;
 const key=(mode,r)=>mode==='accounts'?r.user_id:mode==='access'?r.user_id+':'+r.track_id:r.id;
 const name=r=>r.title||r.full_name||r.email||r.name||r.code||r.id;
 const rpc=async(action,args)=>{const r=await sb.rpc(action,args);if(r.error)throw new Error(r.error.message);return r.data;};
 const dateValue=id=>val(id)?new Date(val(id)).toISOString():null;
 function options(mode){
  return ({accounts:[['active','Activate accounts'],['suspended','Suspend accounts'],['enroll','Grant student track access'],['pause','Pause student track access']],exams:[['publish','Publish'],['unpublish','Unpublish'],['category','Change category'],['assign','Assign to student or group'],['review','Release worked review']],devices:[['revoke','Revoke selected devices']],access:[['active','Activate course access'],['paused','Pause course access'],['dates','Set course dates'],['label','Set course / exam cycle'],['payment','Set payment status']],plans:[['dates','Set course and target exam dates'],['text','Set teaching plan']],reserve:[['reserve','Move to reserve'],['restore','Return to catalogue']]})[mode]||[];
 }
 function mount(mode,rows,table){
  if(!table)return;
  const next=[ST.view,ST.track,mode].join('|');if(scope!==next){scope=next;selected=new Map();}
  const adminOnly=['accounts','devices','access','reserve'].includes(mode);
  if(adminOnly&&ST.me?.role!=='admin')return;
  const allowed=r=>mode==='accounts'?r.role!=='admin'&&r.user_id!==ST.me.id:mode==='devices'?!r.revoked_at:mode==='plans'?r.name!==(ST.tracks.find(t=>t.id===r.track_id)?.name||'')+' — all students':true;
  // Versions/hashes stay current for selected rows when a page is reloaded.
  rows.forEach(r=>{if(selected.has(key(mode,r))){if(allowed(r))selected.set(key(mode,r),r);else selected.delete(key(mode,r));}});
  const header=table.querySelector('tr');if(!header)return;
  const head=document.createElement('th');head.innerHTML='<input type="checkbox" data-bulk-all aria-label="Select all eligible rows shown">';header.prepend(head);
  [...table.querySelectorAll('tr')].slice(1).forEach((tr,i)=>{
   const r=rows[i];if(!r)return;const cell=document.createElement('td');cell.dataset.label='Select';
   if(allowed(r)){const input=document.createElement('input');input.type='checkbox';input.dataset.bulkPick=key(mode,r);input.setAttribute('aria-label','Select '+name(r));input.checked=selected.has(key(mode,r));input.onchange=()=>{input.checked?selected.set(key(mode,r),r):selected.delete(key(mode,r));update();};cell.append(input);}
   tr.prepend(cell);
  });
  $('view').querySelector('[data-bulk-toolbar]')?.remove();
  const bar=document.createElement('div');bar.className='bulk-toolbar';bar.dataset.bulkToolbar=mode;
  bar.innerHTML=`<button type="button" class="btn-sm" data-bulk-shown>Select shown</button><button type="button" class="btn-sm" data-bulk-clear>Clear selection</button><span data-bulk-count role="status"></span><label>Apply one action<select data-bulk-action><option value="">Choose an action</option>${options(mode).map(([v,t])=>`<option value="${v}">${esc(t)}</option>`).join('')}</select></label><button type="button" class="btn" data-bulk-apply disabled>Apply to selected</button>`;
  table.closest('.table-wrap')?.before(bar);if(!bar.isConnected)table.before(bar);
  const inputs=()=>[...table.querySelectorAll('[data-bulk-pick]')];
  function update(){const list=inputs(),count=list.filter(b=>selected.has(b.dataset.bulkPick)).length;list.forEach(b=>b.checked=selected.has(b.dataset.bulkPick));const all=head.firstElementChild;all.checked=list.length>0&&count===list.length;all.indeterminate=count>0&&count<list.length;all.disabled=!list.length||busy;bar.querySelector('[data-bulk-count]').textContent=`${selected.size} selected · ${count} on this page`;bar.querySelector('[data-bulk-apply]').disabled=busy||!selected.size||!bar.querySelector('select').value;}
  head.firstElementChild.onchange=e=>{rows.filter(allowed).forEach(r=>e.target.checked?selected.set(key(mode,r),r):selected.delete(key(mode,r)));update();};
  bar.querySelector('[data-bulk-shown]').onclick=()=>{rows.filter(allowed).forEach(r=>selected.set(key(mode,r),r));update();};
  bar.querySelector('[data-bulk-clear]').onclick=()=>{selected.clear();update();};bar.querySelector('select').onchange=update;
  bar.querySelector('[data-bulk-apply]').onclick=async()=>{if(preparing)return;preparing=true;bar.querySelector('[data-bulk-apply]').disabled=true;try{await prepare(mode,bar.querySelector('select').value,[...selected.values()],update);}catch(e){alert(e.message);}finally{preparing=false;update();}};
  update();
 }
 async function prepare(mode,action,items,update){
  if(busy||!items.length)return;const initialScope=scope;
  let body='',write;
  if(mode==='accounts'){
   if(['enroll','pause'].includes(action)){
    if(items.some(r=>r.role!=='student'))throw new Error('Track access applies to students. Select student accounts only.');
    body=select('bulkTrack','Track',tracks());
    write=()=>{const track=val('bulkTrack');if(!track)throw new Error('Choose a track.');return r=>mutation('enrollment.save',{user_id:r.user_id,track_id:track,status:action==='enroll'?'active':'paused'});};
   }else{body='<p>Administrator accounts and your own account are excluded.</p>';write=()=>r=>mutation('user.update',{id:r.user_id,status:action});}
  }else if(mode==='exams'){
   if(action==='category'){body=select('bulkCategory','Category',[['lesson_exam','Lesson exam'],['quiz','Quiz'],['full_exam','Full exam']]);write=()=>{const category=val('bulkCategory');return r=>mutation('exam.classify',{id:r.id,assessment_type:category});};}
   else if(action==='assign'){
    if(new Set(items.map(r=>r.track_id)).size!==1)throw new Error('Select exams from one track to assign them together.');
    const track=items[0].track_id,[roster,groups,assignments]=await Promise.all([getRows('roster'),getRows('groups'),getRows('assignments')]);
    const targets=[...groups.filter(g=>g.track_id===track).map(g=>['g:'+g.id,'Group: '+g.name]),...roster.filter(r=>r.role==='student'&&r.tracks.split(', ').includes(track)).map(r=>['u:'+r.user_id,'Student: '+name(r)])];
    if(!targets.length)throw new Error('No eligible students or groups in this track.');
    body=select('bulkTarget','Assign to',targets)+field('bulkOpen','Opens at (your device local time)','','datetime-local')+field('bulkClose','Closes at (optional)','','datetime-local')+'<p>Existing assignments to this target are kept and skipped. New assignments use the dates below.</p>';
    write=()=>{const [type,id]=val('bulkTarget').split(':'),open=dateValue('bulkOpen'),close=dateValue('bulkClose');if(open&&close&&close<=open)throw new Error('Closing time must be after opening time.');return async r=>{if(assignments.some(a=>a.exam_id===r.id&&(type==='g'?a.group_id===id:a.user_id===id)))return 'skipped';await mutation('assignment.save',{exam_id:r.id,group_id:type==='g'?id:null,user_id:type==='u'?id:null,open_at:open,close_at:close});};};
   }else if(action==='review'){body='<p>Release worked answers for completed attempts. Exams with an open assignment window will be refused by the server.</p>';write=()=>r=>mutation('review.release',{exam_id:r.id});}
   else{body='<p>Students can open published exams when they also have an assignment.</p>';write=()=>r=>mutation('exam.save',{id:r.id,is_published:action==='publish'});}
  }else if(mode==='devices'){
   body='<p>Revoke access from all selected device sessions. Students will need to sign in again.</p>';write=()=>r=>mutation('device.revoke',{id:r.id});
  }else if(mode==='access'){
   if(action==='dates')body=field('bulkStart','Access starts (blank = immediately)','','datetime-local')+field('bulkEnd','Access ends (blank = no limit)','','datetime-local');
   if(action==='label')body=field('bulkLabel','Course / exam cycle');
   if(action==='payment')body=select('bulkPayment','Payment status',[['unrecorded','Not recorded'],['pending','Pending'],['paid','Paid'],['waived','Complimentary']])+'<p>This changes the status only. It does not record receipts or charge students.</p>';
   write=()=>{const patch={};if(action==='dates'){patch.starts_at=dateValue('bulkStart');patch.ends_at=dateValue('bulkEnd');if(patch.starts_at&&patch.ends_at&&patch.ends_at<=patch.starts_at)throw new Error('End must be after start.');}else if(action==='label'){patch.course_label=val('bulkLabel');if(patch.course_label.length>120)throw new Error('Course label must be at most 120 characters.');}else if(action==='payment')patch.payment_status=val('bulkPayment');else patch.status=action;
    return r=>rpc('admin_save_course_access',{p_user:r.user_id,p_track:r.track_id,p_expected_version:r.access_version,p_data:{status:r.status,payment_status:r.payment_status,course_label:r.course_label,starts_at:r.starts_at,ends_at:r.ends_at,...patch}});};
  }else if(mode==='plans'){
   body=action==='dates'?field('bulkPlanStart','Course starts','','date')+field('bulkPlanEnd','Course ends','','date')+field('bulkPlanExam','Target exam date','','date'):area('bulkPlanText','Teaching plan');
   write=()=>{const patch=action==='dates'?{course_starts_on:val('bulkPlanStart')||null,course_ends_on:val('bulkPlanEnd')||null,target_exam_date:val('bulkPlanExam')||null}:{teaching_plan:val('bulkPlanText')};if(patch.course_starts_on&&patch.course_ends_on&&patch.course_ends_on<patch.course_starts_on)throw new Error('Course end must not be before its start.');if((patch.teaching_plan||'').length>4000)throw new Error('Teaching plan must be at most 4000 characters.');
    return r=>rpc('staff_save_group_plan',{p_group:r.id,p_expected_version:r.plan_version,p_data:{course_starts_on:r.course_starts_on,course_ends_on:r.course_ends_on,target_exam_date:r.target_exam_date,teaching_plan:r.teaching_plan,daily_lessons:r.daily_lessons,...patch}});};
  }else if(mode==='reserve'){
   body=area('bulkReason','Reason (5–500 characters)')+'<p>Existing exams and question history remain attached. Held questions retain their review holds.</p>';
   write=()=>{const reason=val('bulkReason');if(reason.length<5||reason.length>500)throw new Error('Enter a reason of 5–500 characters.');return r=>rpc('staff_question_reserve',{p_question:r.id,p_reserve:action==='reserve',p_reason:reason,p_expected_hash:r.assets_hash});};
  }
  if(!write||scope!==initialScope)return;
  const label=options(mode).find(x=>x[0]===action)[1],editor=$('editor');let remaining=items.slice(),touched=false;
  editor.innerHTML=`<form id="bulkForm"><h2>${esc(label)}</h2><p><b>${items.length} selected items</b>, including selections on other pages.</p><details><summary>Review selected items</summary><ul>${items.map(r=>`<li>${esc(name(r))}${r.track_id?' · '+esc(r.track_id):''}</li>`).join('')}</ul></details>${body}<p id="bulkProgress" role="status"></p><div id="bulkErrors" role="alert"></div><div class="actions"><button class="btn" id="bulkSave">Apply to ${items.length} selected</button><button class="btn-sm" type="button" id="bulkCancel">Cancel</button></div></form>`;
  editor.onclose=async()=>{editor.onclose=null;editor.oncancel=null;if(touched)await render();};
  const cancel=()=>{if(!busy)editor.close();};$('bulkCancel').onclick=cancel;editor.oncancel=e=>{if(busy)e.preventDefault();};
  $('bulkForm').onsubmit=async event=>{
   event.preventDefault();if(busy)return;let apply;try{apply=write();}catch(e){$('bulkErrors').textContent=e.message;return;}
   busy=true;touched=true;const controls=[...document.querySelectorAll('#view button,#view input,#view select,#trackSel,#tabs button,#adminSection,#outBtn,#editor button,#editor input,#editor select,#editor textarea')].map(el=>[el,el.disabled]);controls.forEach(([el])=>el.disabled=true);
   let done=0,skipped=0;const failed=[];$('bulkErrors').textContent='';
   try{for(const r of remaining){$('bulkProgress').textContent=`Processing ${done+failed.length+1} of ${remaining.length}…`;try{const result=await apply(r);if(result==='skipped')skipped++;done++;selected.delete(key(mode,r));}catch(e){failed.push({r,message:e.message||'Could not save'});}}
    remaining=failed.map(x=>x.r);$('bulkProgress').textContent=`${done-skipped} updated · ${skipped} already assigned · ${failed.length} failed.`;
    $('bulkErrors').textContent=failed.map(x=>name(x.r)+': '+x.message).join('\n');$('bulkSave').textContent=failed.length?`Retry ${failed.length} failed items`:'Done';
   }finally{busy=false;controls.forEach(([el,disabled])=>el.disabled=disabled);update();}
   if(!remaining.length){$('bulkSave').disabled=true;$('bulkCancel').textContent='Close';$('bulkCancel').onclick=()=>editor.close();}
   else $('bulkCancel').onclick=()=>editor.close();
  };
  editor.showModal();
 }
 window.AdminBulk={mount,reset(){scope='';selected=new Map();}};
 // Page/search refresh retains selection; changing section or global track clears it.
 const original=render;let last='';render=async function(){const next=ST.view+'|'+ST.track;if(next!==last){window.AdminBulk.reset();last=next;}return original.apply(this,arguments);};
})();
