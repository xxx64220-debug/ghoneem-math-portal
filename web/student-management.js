// One student workspace for account details, subscriptions and teaching groups.
(function(){
 'use strict';
 const $s=id=>document.getElementById(id),rpc=async(name,args)=>{const r=await sb.rpc(name,args);if(r.error)throw new Error(r.error.message);return r.data;};
 const local=t=>{if(!t)return '';const d=new Date(t);return new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,16);};
 const date=t=>t?new Date(t).toLocaleDateString('en-GB',{timeZone:'Africa/Cairo'}):'No limit';
 const state=e=>e.status==='paused'?'Paused':e.starts_at&&new Date(e.starts_at)>new Date()?'Starts '+date(e.starts_at):e.ends_at&&new Date(e.ends_at)<=new Date()?'Expired':'Active';
 const error=e=>({access_changed_refresh:'A subscription changed while the form was open. Close and reopen the student to load its latest setup.',admin_required:'Only active administrators can manage student subscriptions.',group_course_mismatch:'Each selected group must have a matching course.',end_must_follow_start:'Access end must be after its start.'})[e.message]||e.message||'Could not save student setup.';
 async function loadSetup(user_id){
  const [groups,courses,members,profiles]=await Promise.all([getRows('groups'),user_id?getRows('enrollments',false,'*','','user_id',user_id):[],user_id?getRows('group_members',false,'*','','user_id',user_id):[],user_id?getRows('profiles',false,'id,full_name,email,role,status','','id',user_id):[]]);
  const profile=profiles[0]||null;if(user_id&&(!profile||profile.role!=='student'))throw new Error('Student account is unavailable. Refresh the list.');
  return {profile,courses,group_ids:members.map(m=>m.group_id),groups:groups.map(g=>({...g,is_default:g.name===(ST.tracks.find(t=>t.id===g.track_id)?.name||'')+' — all students'}))};
 }
 const courseMatches=(e,c)=>['status','payment_status','course_label'].every(k=>(e[k]||'')===(c[k]||''))&&['starts_at','ends_at'].every(k=>(e[k]?new Date(e[k]).toISOString():null)===(c[k]||null));
 async function saveSetup(user_id,payload,known,progress){
  for(const course of payload.courses){
   let expected=known.courses.find(e=>e.track_id===course.track_id);
   if(!expected){progress.textContent='Adding '+course.track_id+' course…';await mutation('enrollment.save',{user_id,track_id:course.track_id,status:'active'});const rows=await getRows('enrollments',false,'*','','user_id',user_id);expected=rows.find(e=>e.track_id===course.track_id);if(!expected)throw new Error('Course enrollment could not be confirmed. Retry to continue.');known.courses.push(expected);}
   if(!courseMatches(expected,course)){
    progress.textContent='Saving '+course.track_id+' subscription…';
    try{const data=await rpc('admin_save_course_access',{p_user:user_id,p_track:course.track_id,p_expected_version:expected.access_version,p_data:course});Object.assign(expected,data);}
    catch(e){const rows=await getRows('enrollments',false,'*','','user_id',user_id),latest=rows.find(x=>x.track_id===course.track_id);if(latest&&courseMatches(latest,course))Object.assign(expected,latest);else throw e;}
   }
  }
  const courses=new Set(payload.courses.map(e=>e.track_id)),wanted=new Set(payload.group_ids);
  if([...wanted].some(id=>!known.groups.some(g=>g.id===id&&courses.has(g.track_id))))throw new Error('Each selected group must match a selected course.');
  progress.textContent='Saving teaching-group assignments…';
  const preferences=(payload.daily_groups||[]).filter(p=>(known.courses.find(e=>e.track_id===p.track_id)?.daily_group_id??null)!==p.group_id);
  const add=[...wanted].filter(id=>!known.group_ids.includes(id)),remove=known.group_ids.filter(id=>!wanted.has(id)&&!known.groups.some(g=>g.id===id&&g.is_default));
  if(add.length||remove.length||preferences.length){const r=await fn('student-groups',{body:{user_id,add,remove,...(preferences.length?{daily_groups:preferences}:{})}});if(!r.ok)throw new Error(r.json.error||'Could not save group assignments.');known.group_ids=known.group_ids.filter(id=>!remove.includes(id));add.forEach(id=>{if(!known.group_ids.includes(id))known.group_ids.push(id);});preferences.forEach(p=>{const e=known.courses.find(e=>e.track_id===p.track_id);if(e)e.daily_group_id=p.group_id;});}
  // The profile is applied last. New students remain suspended until setup completes.
  progress.textContent='Saving account details…';await mutation('user.update',{id:user_id,full_name:payload.full_name,status:payload.status});known.profile={...known.profile,full_name:payload.full_name,status:payload.status};return known;
 }
 let page=0,search='',filter='all',request=0,lastTrack=null;
 function tabs(current){return `<div class="student-admin-tabs"><button class="btn-sm" data-student-tab="registrations">Registration requests</button><button class="btn-sm ${current==='students'?'on':''}" data-student-tab="students" ${current==='students'?'aria-current="page"':''}>Accounts & groups</button><button class="btn-sm ${current==='subscriptions'?'on':''}" data-student-tab="subscriptions" ${current==='subscriptions'?'aria-current="page"':''}>Subscriptions & payments</button></div>`;}
 function bindTabs(){document.querySelectorAll('[data-student-tab]').forEach(b=>b.onclick=()=>{ST.view=b.dataset.studentTab;render();});}
 const originalStudents=students,originalManage=manageUser;
 students=async function(){
  if(ST.me?.role!=='admin')return originalStudents();
  const token=++request,track=ST.track;if(lastTrack!==track){page=0;lastTrack=track;}
  const [all,enrollments,groups,members]=await Promise.all([getRows('roster'),getRows('enrollments'),getRows('groups'),getRows('group_members')]);
  if(token!==request||ST.view!=='students'||ST.track!==track)return;
  const shown=all.filter(r=>(!track||enrollments.some(e=>e.user_id===r.user_id&&e.track_id===track))&&(!search||[r.full_name,r.email,...enrollments.filter(e=>e.user_id===r.user_id).map(e=>e.course_label)].join(' ').toLowerCase().includes(search.toLowerCase()))&&(filter==='all'||filter==='student'&&r.role==='student'||filter==='staff'&&r.role!=='student'||filter==='suspended'&&r.status==='suspended')).sort((a,b)=>sortText(a.full_name,b.full_name));
  page=Math.min(page,Math.max(0,Math.ceil(shown.length/50)-1));const rows=shown.slice(page*50,page*50+50);
  $s('view').innerHTML=`<div class="head"><h2>Students & subscriptions</h2><div class="sp"></div><button class="btn-sm" id="createStaff">Create staff account</button><button class="btn" id="addAccount">Create student</button></div>${tabs('students')}<p class="hint">Create or manage each student’s account, subscriptions and teaching groups together. Payment receipts are available under Subscriptions & payments.</p><div class="control-bar">${field('studentSearch','Find a student or course',search)}${select('studentFilter','Show',[['all','All accounts'],['student','Students'],['staff','Staff'],['suspended','Suspended accounts']],filter)}<button class="btn-sm" id="studentFind">Search</button></div><p role="status">${shown.length} accounts · page ${page+1} of ${Math.max(1,Math.ceil(shown.length/50))}</p>${wrapTable(`<table><thead><tr><th>Student / sign-in</th><th>Role / account</th><th>Subscriptions</th><th>Groups</th><th>Actions</th></tr></thead><tbody>${rows.map(r=>{const courses=enrollments.filter(e=>e.user_id===r.user_id&&(!track||e.track_id===track)),gs=groups.filter(g=>members.some(m=>m.group_id===g.id&&m.user_id===r.user_id)&&(!track||g.track_id===track));return `<tr><td>${esc(r.full_name||'Unnamed account')}<p class="hint">${esc(r.email)}</p></td><td>${esc(r.role)}<p class="hint">${esc(r.status)}</p></td><td>${courses.length?courses.map(e=>`<div class="student-course-summary"><b>${esc(ST.tracks.find(t=>t.id===e.track_id)?.name||e.track_id)}</b> · ${esc(state(e))}<small>${esc(e.course_label||'Course name not set')} · ${esc(e.payment_status)}</small><small>Ends: ${esc(date(e.ends_at))}</small></div>`).join(''):r.role==='student'?'No subscription yet':'Staff access'}</td><td>${gs.length?gs.map(g=>esc(g.name)).join('<br>'):'No teaching group'}</td><td><button class="btn-sm" data-user="${r.user_id}">${r.role==='student'?'Manage student':'Manage account'}</button>${r.role!=='admin'&&r.user_id!==ST.me.id?` <button class="btn-sm danger" data-delete-user="${r.user_id}">Delete</button>`:''}</td></tr>`;}).join('')}</tbody></table>`)}<div class="actions"><button class="btn-sm" id="studentPrev" ${page===0?'disabled':''}>Previous</button><button class="btn-sm" id="studentNext" ${(page+1)*50>=shown.length?'disabled':''}>Next</button></div>`;
  bindTabs();$s('addAccount').onclick=()=>open().catch(e=>alert(error(e)));$s('createStaff').onclick=createStaff;
  document.querySelectorAll('[data-user]').forEach(b=>b.onclick=()=>manageUser(rows.find(r=>r.user_id===b.dataset.user)));
  document.querySelectorAll('[data-delete-user]').forEach(b=>b.onclick=()=>deleteAccount(rows.find(r=>r.user_id===b.dataset.deleteUser)));
  $s('studentFind').onclick=()=>{search=val('studentSearch');page=0;students().catch(e=>alert(error(e)));};$s('studentSearch').onkeydown=e=>{if(e.key==='Enter')$s('studentFind').click();};$s('studentFilter').onchange=()=>{filter=val('studentFilter');page=0;students().catch(e=>alert(error(e)));};$s('studentPrev').onclick=()=>{page--;students();};$s('studentNext').onclick=()=>{page++;students();};
  window.AdminBulk?.mount('accounts',rows,$s('view').querySelector('table'));
 };
 manageUser=async function(u){if(ST.me?.role!=='admin'||u.role!=='student')return originalManage(u);try{await open(u);}catch(e){alert(error(e));}};
 function createStaff(){
  dialog('Create staff account',field('staffEmail','Email')+field('staffName','Full name')+field('staffPassword','Initial password (at least 8 characters)','','password')+select('staffRole','Role',[['instructor','Instructor'],['admin','Administrator']])+`<fieldset><legend>Instructor track access</legend>${ST.tracks.map(t=>`<label class="check"><input type="checkbox" data-staff-track="${t.id}">${esc(t.name)}</label>`).join('')}</fieldset>`,async()=>{
   const r=await fn('admin-users',{body:{email:val('staffEmail'),full_name:val('staffName'),password:$s('staffPassword').value,role:val('staffRole'),tracks:[]}});if(!r.ok)throw new Error(r.json.error);if(val('staffRole')==='instructor')await mutation('instructor.tracks',{id:r.json.user_id,tracks:[...document.querySelectorAll('[data-staff-track]:checked')].map(b=>b.dataset.staffTrack)});
  },'Create staff account');
 }
 async function open(user){
  if(ST.me?.role!=='admin')throw new Error('admin_required');
  const context=ST.view+'|'+ST.track;let setup=await loadSetup(user?.user_id||null),createdId=null,busy=false,completed=false,creationStaged=false;
  if(context!==ST.view+'|'+ST.track)return;
  const profile=setup.profile||{},existing=new Map(setup.courses.map(e=>[e.track_id,e]));
  const cards=ST.tracks.map((t,i)=>{
   const e=existing.get(t.id),included=!!e||(!user&&ST.track===t.id),groups=setup.groups.filter(g=>g.track_id===t.id&&!g.is_default);
   return `<fieldset class="student-course-card" data-student-course="${esc(t.id)}" data-course-index="${i}"><legend><label class="check"><input type="checkbox" data-course-enabled ${included?'checked':''}>${esc(t.name)}</label></legend><div data-course-fields><div class="grid">${field('scLabel'+i,'Course / exam cycle',e?.course_label||'')}${select('scStatus'+i,'Course access',[['active','Active'],['paused','Paused']],e?.status||'active')}${select('scPayment'+i,'Payment status',[['unrecorded','Not recorded'],['pending','Pending'],['paid','Paid'],['waived','Complimentary']],e?.payment_status||'unrecorded')}${field('scStart'+i,'Access starts (local time; blank = immediately)',local(e?.starts_at),'datetime-local')}${field('scEnd'+i,'Access ends (local time; blank = no limit)',local(e?.ends_at),'datetime-local')}</div><h3>Teaching groups</h3>${groups.length?groups.map(g=>`<label class="check"><input type="checkbox" data-student-group="${g.id}" ${setup.group_ids.includes(g.id)?'checked':''}>${esc(g.name)}</label>`).join(''):'<p class="hint">No teaching groups in this track. Create one under Groups.</p>'}${select('scDaily'+i,'Daily quiz group',[['','Automatic · use a single active group, otherwise track settings'],...groups.map(g=>[g.id,g.name])],e?.daily_group_id||'')}<p class="hint">Select one of this student’s teaching groups. This affects new daily sets; today’s opened quiz stays unchanged. The all-students cohort is retained automatically.</p></div>${e?'<p class="hint">Turning this course off pauses access and retains its saved dates, groups and results.</p>':''}</fieldset>`;
  }).join('');
  dialog(user?'Manage student · '+esc(profile.full_name||profile.email):'Create student',(!user?field('studentLogin','Username or email')+field('studentPassword','Initial password (at least 8 characters)','','password'):'<p>'+esc(profile.email)+'</p>')+field('studentName','Full name',profile.full_name||'')+select('studentStatus','Account status',[['active','Active'],['suspended','Suspended']],profile.status||'active')+'<h3>Subscriptions & group assignments</h3><p class="hint">Choose each course, its access dates and payment status, then select the teaching groups. Payment status does not create a receipt.</p>'+cards+'<p id="studentSetupProgress" role="status"></p>',async()=>{
   if(busy)return;const payload=collect();let login,password;
   if(!user&&!createdId){login=val('studentLogin').toLowerCase();password=$s('studentPassword').value;if(!login||(!login.includes('@')&&!/^[a-z0-9._-]{3,32}$/.test(login)))throw new Error('Enter an email or a username of 3–32 letters, numbers, dots, underscores or hyphens.');if(login.includes('@')&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(login))throw new Error('Enter a valid email.');if(password.length<8)throw new Error('Password must contain at least 8 characters.');}
   busy=true;const controls=[...$s('editor').querySelectorAll('input,select,textarea,button')].map(el=>[el,el.disabled]);controls.forEach(([el])=>el.disabled=true);$s('editor').oncancel=e=>e.preventDefault();
   try{
    if(!user&&!createdId){$s('studentSetupProgress').textContent='Creating account…';const r=await fn('admin-users',{body:{username:login.includes('@')?'':login,email:login.includes('@')?login:undefined,password,full_name:payload.full_name,role:'student',tracks:[]}});if(!r.ok)throw new Error(r.json.error||'Account creation failed.');createdId=r.json.user_id;if(!createdId)throw new Error('Account creation returned no account ID. Refresh the account list before trying again.');$s('studentPassword').value='';}
    if(createdId&&!creationStaged){await mutation('user.update',{id:createdId,status:'suspended'});creationStaged=true;}
    if(createdId&&setup.profile?.id!==createdId)setup=await loadSetup(createdId);
    $s('studentSetupProgress').textContent='Saving subscriptions and teaching groups…';setup=await saveSetup(user?.user_id||createdId,payload,setup,$s('studentSetupProgress'));completed=true;
   }catch(e){$s('studentSetupProgress').textContent=createdId?'Account created. Setup is incomplete; retry to continue the same account. Completed course changes are retained.':'Some changes may already be saved. Retry to continue, or reopen the student if a subscription changed elsewhere.';throw new Error(error(e));}
   finally{busy=false;controls.forEach(([el,disabled])=>el.disabled=disabled);$s('editor').oncancel=null;if(createdId){$s('studentLogin').disabled=true;$s('studentPassword').disabled=true;$s('editSave').textContent='Save student setup';}}
  },user?'Save account, subscriptions & groups':'Create student with subscriptions & groups');
  $s('studentName').maxLength=200;
  document.querySelectorAll('[data-student-course]').forEach(card=>{
   const i=card.dataset.courseIndex;$s('scLabel'+i).maxLength=120;
   const enabled=card.querySelector('[data-course-enabled]'),fields=card.querySelector('[data-course-fields]');
   const paint=()=>{fields.hidden=!enabled.checked;fields.querySelectorAll('input,select').forEach(el=>el.disabled=!enabled.checked);};enabled.onchange=paint;card.querySelectorAll('[data-student-group]').forEach(b=>b.onchange=()=>{const current=val('scDaily'+i);if(current&&!card.querySelector('[data-student-group="'+current+'"]')?.checked)$s('scDaily'+i).value='';});paint();
  });
  // A successfully created account stays available if the admin closes after a later setup failure.
  $s('editor').onclose=async()=>{$s('editor').onclose=null;if(createdId&&!completed)await render();};
  function collect(){
   const full_name=val('studentName');if(!full_name||full_name.length>200)throw new Error('Enter the student’s full name (up to 200 characters).');
   const courses=[],daily_groups=[],group_ids=new Set(setup.group_ids.filter(id=>!setup.groups.some(g=>g.id===id&&ST.tracks.some(t=>t.id===g.track_id)&&!g.is_default)));
   document.querySelectorAll('[data-student-course]').forEach(card=>{
    const track_id=card.dataset.studentCourse,i=card.dataset.courseIndex,enabled=card.querySelector('[data-course-enabled]').checked,old=existing.get(track_id);
    if(!enabled&&!old)return;
    const starts_at=val('scStart'+i)?new Date(val('scStart'+i)).toISOString():null,ends_at=val('scEnd'+i)?new Date(val('scEnd'+i)).toISOString():null;
    if(starts_at&&ends_at&&ends_at<=starts_at)throw new Error('Access end must be after its start for '+track_id+'.');
    courses.push({track_id,status:enabled?val('scStatus'+i):'paused',payment_status:val('scPayment'+i),course_label:val('scLabel'+i),starts_at,ends_at});
    card.querySelectorAll('[data-student-group]:checked').forEach(b=>group_ids.add(b.dataset.studentGroup));
    const daily=val('scDaily'+i)||null;if(daily&&!group_ids.has(daily))throw new Error('Choose a daily quiz group that is checked for this student.');daily_groups.push({track_id,group_id:daily});
   });
   // Keep any legacy course which the current navigation does not list.
   for(const e of existing.values())if(!ST.tracks.some(t=>t.id===e.track_id))courses.push({track_id:e.track_id,status:e.status,payment_status:e.payment_status,course_label:e.course_label,starts_at:e.starts_at,ends_at:e.ends_at});
   return {full_name,status:val('studentStatus'),courses,group_ids:[...group_ids],daily_groups};
  }
 }
 function decorate(){
  document.querySelectorAll('#tabs [data-v="students"],#adminSection option[value="students"]').forEach(el=>el.textContent=ST.me?.role==='instructor'?'Students':'Students & subscriptions');
  // Subscriptions remains a supported internal route, under the same primary destination.
  document.querySelectorAll('#tabs [data-v="subscriptions"],#adminSection option[value="subscriptions"]').forEach(el=>el.hidden=true);
  if(ST.view==='subscriptions'&&ST.me?.role==='admin'&&!$s('view').querySelector('[data-student-tab]')){
   const h=$s('view').querySelector('.head');if(h){h.querySelector('h2').textContent='Students & subscriptions';h.insertAdjacentHTML('afterend',tabs('subscriptions'));bindTabs();}
  }
 }
 const originalRender=render;render=async function(){await originalRender.apply(this,arguments);decorate();};
 const originalSync=syncAdminNavigation;syncAdminNavigation=function(){const view=ST.view;if(view==='subscriptions')ST.view='students';try{return originalSync.apply(this,arguments);}finally{ST.view=view;}};
 window.StudentHub={open,decorate,saveSetup};decorate();
})();
