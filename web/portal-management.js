// Additive staff management. Every action is authorized again in the database.
(function(){
 'use strict';
 const el=id=>document.getElementById(id),safe=s=>esc(s),date=t=>t?new Date(t).toLocaleString('en-GB',{timeZone:'Africa/Cairo',dateStyle:'medium',timeStyle:'short'}):'No limit';
 const local=t=>{if(!t)return '';const d=new Date(t);return new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,16);};
 const iso=id=>el(id).value?new Date(el(id).value).toISOString():null;
 let serial=0,courseFilter='all',courseSearch='',coursePage=0,bankFilter='all',bankPage=0,bankGroup='',bankCycle='',lastTrack=null;
 const rpc=async(name,args={})=>{const r=await sb.rpc(name,args);if(r.error)throw new Error(r.error.message);return r.data;};
 const active=()=>ST.track||'';
 const paramsReset=()=>{if(lastTrack!==active()){lastTrack=active();coursePage=bankPage=0;bankGroup=bankCycle='';}};
 const nav=(id,label,adminOnly=false)=>{
  const root=document.querySelector('#tabs>.wrap');if(!root)return;
  const b=document.createElement('button');b.className='tab';b.dataset.v=id;b.textContent=label;b.dataset.managementAdmin=adminOnly?'true':'false';
  root.append(b);const o=document.createElement('option');o.value=id;o.textContent=label;o.dataset.managementAdmin=b.dataset.managementAdmin;el('adminSection')?.append(o);
 };
 if(typeof ST!=='undefined'&&typeof render==='function'&&el('adminSection')){
  nav('subscriptions','Course access',true);nav('coursePlans','Course plans');nav('bankOperations','Bank usage & cycles');
  const original=render;
  render=async function(){
   serial++;paramsReset();document.querySelectorAll('[data-management-admin="true"]').forEach(x=>x.hidden=ST.me?.role!=='admin');
   if(!['subscriptions','coursePlans','bankOperations'].includes(ST.view))return original.apply(this,arguments);
   if(ST.view==='subscriptions'&&ST.me?.role!=='admin'){el('view').textContent='Course access is managed by the administrator.';return;}
   syncAdminNavigation();el('view').innerHTML='<p role="status">Loading…</p>';
   const n=serial;try{if(ST.view==='subscriptions')await subscriptions(n);else if(ST.view==='coursePlans')await plans(n);else await operations(n);}catch(e){if(n===serial)el('view').innerHTML=`<p class="management-error" role="alert">${safe(e.message)}</p><button class="btn-sm" id="managementRetry">Try again</button>`;el('managementRetry')?.addEventListener('click',()=>render());}
  };
 }
 function pager(page,total,move){
  const pages=Math.max(1,Math.ceil(total/50));el('managementPager').innerHTML=`<button class="btn-sm" id="managementPrev" ${page===0?'disabled':''}>Previous</button><span>Page ${page+1} of ${pages} · ${total} records</span><button class="btn-sm" id="managementNext" ${(page+1)*50>=total?'disabled':''}>Next</button>`;
  el('managementPrev').onclick=()=>move(page-1);el('managementNext').onclick=()=>move(page+1);
 }
 async function subscriptions(n){
  const data=await rpc('admin_course_enrollments',{p_track:active(),p_filter:courseFilter,p_search:courseSearch,p_page:coursePage});if(n!==serial)return;
  el('view').innerHTML=`<div class="head"><h2>Course access & payments</h2></div><p class="management-note">Keep one account per student. Set course dates when agreed; existing access has no automatic expiry. Payment records document money already received. Access and payment status are saved separately.</p><div class="grid">${Object.entries(data.summary).map(([k,v])=>`<div class="stat"><div class="k">${safe(k)}</div><div class="v">${v}</div></div>`).join('')}</div><div class="management-toolbar"><label>Access or payment status<select id="courseFilter">${['all','active','expiring','expired','future','paused','pending','unrecorded'].map(x=>`<option ${courseFilter===x?'selected':''}>${x}</option>`).join('')}</select></label><label>Find a student or course<input id="courseSearch" type="search" maxlength="200" value="${safe(courseSearch)}"></label><button class="btn-sm" id="courseFind">Search</button><button class="btn-sm" id="courseExport">Export displayed rows</button></div>${wrapTable(`<table class="management-table"><thead><tr><th>Student</th><th>Track / course</th><th>Access</th><th>Dates · Cairo</th><th>Payment</th><th>Actions</th></tr></thead><tbody>${data.items.map((r,i)=>`<tr><td>${safe(r.full_name||r.email)}<small>${safe(r.email)}</small>${r.account_status!=='active'?'<small>Account suspended</small>':''}</td><td>${safe(r.track_id.toUpperCase())}<small>${safe(r.course_label||'Course name not set')}</small></td><td>${safe(r.access_state)}</td><td>Start: ${r.starts_at?safe(date(r.starts_at)):'Immediately'}<small>End: ${safe(date(r.ends_at))}</small></td><td>${safe(r.payment_status)}</td><td><div class="management-actions"><button class="btn-sm" data-access="${i}">Edit / renew</button><button class="btn-sm" data-payment="${i}">Record payment</button><button class="btn-sm" data-ledger="${i}">Payment history</button></div></td></tr>`).join('')}</tbody></table>`)}${!data.items.length?'<p>No matching enrollments. Add track access from Students → Manage account.</p>':''}<div id="managementPager" class="management-pager"></div>`;
  el('courseFilter').onchange=e=>{courseFilter=e.target.value;coursePage=0;render();};el('courseFind').onclick=()=>{courseSearch=el('courseSearch').value;coursePage=0;render();};el('courseSearch').onkeydown=e=>{if(e.key==='Enter')el('courseFind').click();};
  el('courseExport').onclick=()=>csv(data.items.map(({user_id,full_name,track_id,course_label,access_state,starts_at,ends_at,payment_status,account_status})=>({user_id,full_name,track_id,course_label,access_state,starts_at,ends_at,payment_status,account_status})),'course-access');
  document.querySelectorAll('[data-access]').forEach(b=>b.onclick=()=>{const r=data.items[+b.dataset.access];if(window.StudentHub)window.StudentHub.open({user_id:r.user_id}).catch(e=>alert(e.message));else editAccess(r);});
  document.querySelectorAll('[data-payment]').forEach(b=>b.onclick=()=>payment(data.items[+b.dataset.payment]));
  document.querySelectorAll('[data-ledger]').forEach(b=>b.onclick=()=>ledger(data.items[+b.dataset.ledger]));
  window.AdminBulk?.mount('access',data.items,el('view').querySelector('table'));
  pager(coursePage,data.total,p=>{coursePage=p;render();});
 }
 function editAccess(r){
  dialog('Course access · '+safe(r.full_name||r.email),field('courseLabel','Course / exam cycle',r.course_label)+select('courseStatus','Permission',[['active','Active'],['paused','Paused']],r.status)+field('courseStart','Access starts at (your device local time; blank = immediately)',local(r.starts_at),'datetime-local')+field('courseEnd','Access ends at (your device local time; blank = no limit)',local(r.ends_at),'datetime-local')+select('coursePayment','Payment status',[['unrecorded','Not recorded'],['pending','Pending'],['paid','Paid'],['waived','Complimentary']],r.payment_status)+`<p class="management-note">Expiry stops new practice. Saved results remain available. A timed exam already started can finish through its deadline. Pausing access stops exam activity immediately.</p>`,async()=>{
   const starts_at=iso('courseStart'),ends_at=iso('courseEnd');if(starts_at&&ends_at&&ends_at<=starts_at)throw new Error('End must be after start.');
   await rpc('admin_save_course_access',{p_user:r.user_id,p_track:r.track_id,p_expected_version:r.access_version,p_data:{status:val('courseStatus'),payment_status:val('coursePayment'),course_label:val('courseLabel'),starts_at,ends_at}});
  });el('courseLabel').maxLength=120;
 }
 function payment(r){
  const request=crypto.randomUUID(),today=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  dialog('Record received payment · '+safe(r.full_name||r.email),field('paymentAmount','Amount received','','number')+field('paymentCurrency','Currency','EGP')+field('paymentDate','Date received',today,'date')+field('paymentReference','Receipt / transfer reference')+`<p class="management-note">This records a payment already received. It does not charge the student or automatically change course access. Check the amount before saving.</p>`,async()=>{
   const amount=Number(val('paymentAmount'));if(!Number.isFinite(amount)||amount<=0||Math.round(amount*100)/100!==amount)throw new Error('Enter a positive amount with at most two decimal places.');
   await rpc('admin_record_course_payment',{p_user:r.user_id,p_track:r.track_id,p_amount:amount,p_currency:val('paymentCurrency').toUpperCase(),p_paid_on:val('paymentDate'),p_reference:val('paymentReference'),p_request:request});
  },'Record received payment');el('paymentAmount').min='0.01';el('paymentAmount').step='0.01';el('paymentCurrency').maxLength=3;el('paymentReference').maxLength=200;el('paymentDate').required=true;el('paymentDate').max=today;
 }
 async function ledger(r){
  try{const q=await sb.from('course_payments').select('amount,currency,paid_on,reference,recorded_at').eq('user_id',r.user_id).eq('track_id',r.track_id).order('recorded_at',{ascending:false}).limit(100);if(q.error)throw q.error;
   el('editor').innerHTML=`<h2>Payment history · ${safe(r.full_name||r.email)}</h2><p>${safe(r.track_id.toUpperCase())} · Latest 100 receipts. Renewals remain attached to this account.</p>${wrapTable(`<table><tr><th>Received</th><th>Amount</th><th>Reference</th></tr>${q.data.map(x=>`<tr><td>${safe(x.paid_on)}</td><td>${safe(x.amount)} ${safe(x.currency)}</td><td>${safe(x.reference)}</td></tr>`).join('')}</table>`)}${q.data.length?'':'<p>No payments recorded yet.</p>'}<button class="btn-sm" id="ledgerClose">Close</button>`;el('ledgerClose').onclick=()=>el('editor').close();el('editor').showModal();
  }catch(e){alert(e.message);}
 }
 async function plans(n){
  const rows=(await getRows('groups',true)).filter(g=>g.name!==(ST.tracks.find(t=>t.id===g.track_id)?.name||'')+' — all students');if(n!==serial)return;
  el('view').innerHTML=`<div class="head"><h2>Course plans</h2></div><p class="management-note">Set each group’s exam target and current daily-quiz lessons. Use Diagnose → Reteach → Worksheet → Quiz → Retest each week. Empty lesson selection inherits the track’s daily settings. Today’s quiz stays frozen after a student opens it.</p>${wrapTable(`<table class="management-table"><tr><th>Group</th><th>Course dates</th><th>Exam target</th><th>Daily lessons</th><th>Teaching plan</th><th></th></tr>${rows.map((g,i)=>`<tr><td>${safe(g.name)}<small>${safe(g.track_id.toUpperCase())}</small></td><td>${safe(g.course_starts_on||'Not set')} → ${safe(g.course_ends_on||'Not set')}</td><td>${safe(g.target_exam_date||'Not set')}</td><td>${safe(g.daily_lessons.join(', ')||'Track settings')}</td><td>${safe(g.teaching_plan)}</td><td><button class="btn-sm" data-plan="${i}">Plan group</button></td></tr>`).join('')}</table>`)}${rows.length?'':'<p>Create a group from Groups first.</p>'}`;
  window.AdminBulk?.mount('plans',rows,el('view').querySelector('table'));
  document.querySelectorAll('[data-plan]').forEach(b=>b.onclick=()=>editPlan(rows[+b.dataset.plan]));
 }
 async function editPlan(g){
  try{const lessons=await rpc('staff_course_lessons',{p_track:g.track_id});dialog('Plan · '+safe(g.name),field('planStart','Course starts',g.course_starts_on,'date')+field('planEnd','Course ends',g.course_ends_on,'date')+field('planExam','Target exam date',g.target_exam_date,'date')+area('planText','Weekly teaching plan',g.teaching_plan)+`<fieldset class="management-fieldset"><legend>Current daily-quiz lessons · select any lessons in this track</legend><button type="button" class="btn-sm" id="planSelectLessons">Select all lessons</button> <button type="button" class="btn-sm" id="planClearLessons">Clear lesson selection</button>${lessons.map((x,i)=>`<label><input type="checkbox" data-plan-lesson="${i}" ${g.daily_lessons.includes(x)?'checked':''}>${safe(x)}</label>`).join('')}</fieldset><p class="hint">Select lessons with at least five ready, verified multiple-choice questions. Choose each student’s daily quiz group in Students & subscriptions. Automatic selection uses a group only when exactly one teaching group is active; multiple groups inherit track settings until a group is chosen.</p>`,async()=>{
   const selected=[...document.querySelectorAll('[data-plan-lesson]:checked')].map(b=>lessons[+b.dataset.planLesson]);
   await rpc('staff_save_group_plan',{p_group:g.id,p_expected_version:g.plan_version,p_data:{target_exam_date:val('planExam')||null,course_starts_on:val('planStart')||null,course_ends_on:val('planEnd')||null,teaching_plan:val('planText'),daily_lessons:selected}});
  });el('planText').maxLength=4000;el('planSelectLessons').onclick=()=>document.querySelectorAll('[data-plan-lesson]').forEach(b=>b.checked=true);el('planClearLessons').onclick=()=>document.querySelectorAll('[data-plan-lesson]').forEach(b=>b.checked=false);}catch(e){alert(e.message);}
 }
 async function operations(n){
  if(!active()){el('view').innerHTML='<h2>Bank usage & trial cycles</h2><p>Select a track above to inspect its question use and student evidence.</p>';return;}
  const [gs,cs]=await Promise.all([getRows('groups',true),sb.from('hardest_cycles').select('id,track_id,title,starts_at,ends_at').eq('track_id',active()).order('created_at',{ascending:false})]);if(cs.error)throw cs.error;
  if(bankGroup&&!gs.some(g=>g.id===bankGroup))bankGroup='';if(bankCycle&&!cs.data.some(c=>c.id===bankCycle))bankCycle='';
  const data=await rpc('staff_bank_operations',{p_track:active(),p_group:bankGroup||null,p_cycle:bankCycle||null,p_filter:bankFilter,p_page:bankPage});if(n!==serial)return;
  el('view').innerHTML=`<div class="head"><h2>Bank usage & trial cycles</h2></div><p class="management-note">First and latest success count each student once per question in the selected period. Repeat improvement shows initially wrong students with repeated evidence who later answered correctly. Small samples are marked. Historical Hardest snapshots stay unchanged. “Ready” means structurally complete; independent mathematical review is a separate status.</p><div class="grid">${Object.entries(data.summary).map(([k,v])=>`<div class="stat"><div class="k">${safe(k)}</div><div class="v">${v}</div></div>`).join('')}</div><div class="management-toolbar"><label>Group<select id="opsGroup"><option value="">All permitted students</option>${gs.map(g=>`<option value="${g.id}" ${g.id===bankGroup?'selected':''}>${safe(g.name)}</option>`).join('')}</select></label><label>Trial period<select id="opsCycle"><option value="">All recorded history</option>${cs.data.map(c=>`<option value="${c.id}" ${c.id===bankCycle?'selected':''}>${safe(c.title)}${c.ends_at?' · closed':' · current'}</option>`).join('')}</select></label><label>Question filter<select id="opsFilter">${[['all','All questions'],['hardest','Lowest first success'],['unused','Ready · no published assignment or scored use'],['underused','Assigned · fewer than 3 students'],['held','Incomplete / held'],['pending','Independent review pending'],['reserve','Reserve catalogue']].map(([v,t])=>`<option value="${v}" ${v===bankFilter?'selected':''}>${safe(t)}</option>`).join('')}</select></label><button class="btn-sm" id="opsExport">Export displayed rows</button></div><p class="hint">Reserve keeps a question’s original content and history, and excludes it from new automatic sets. Existing exams remain usable. Usage from daily quizzes and completed scored exams is included; Final Revision and ungraded work are not counted. Group membership is evaluated as it stands today.</p>${wrapTable(`<table class="management-table"><tr><th>Question / lesson</th><th>Quality</th><th>Published use</th><th>Evidence</th><th>First / latest success</th><th>Repeat improvement</th><th>Last use</th>${ST.me.role==='admin'?'<th>Catalogue</th>':''}</tr>${data.items.map((r,i)=>`<tr><td><b>${safe(r.lesson||'Unclassified')}</b><small>${safe(r.code)}</small>${safe(r.stem)}</td><td>${r.ready?'Ready':'Under review'}<small>${safe(r.math_review==='independently_solved'?'Independently solved':'Math review pending')}</small><small>${safe(r.hold_reason)}</small>${r.reserve?'<small>Reserve</small>':''}</td><td>${r.published_exams} exams<small>${r.assignments} current published assignments</small></td><td>${r.unique_students} students<small>${r.responses} responses</small>${r.unique_students<3?'<small>Small sample</small>':''}</td><td>${r.first_success==null?'—':r.first_success+'%'} / ${r.latest_success==null?'—':r.latest_success+'%'}</td><td>${r.repeat_improvement==null?'—':r.repeat_improvement+'%'}<small>${r.improved}/${r.repeat_candidates} initially wrong repeaters</small></td><td>${r.last_used?safe(date(r.last_used)):'No scored use'}</td>${ST.me.role==='admin'?`<td><button class="btn-sm" data-reserve="${i}">${r.reserve?'Return to catalogue':'Move to reserve'}</button></td>`:''}</tr>`).join('')}</table>`)}${data.items.length?'':'<p>No questions match these filters.</p>'}<div id="managementPager" class="management-pager"></div>`;
  for(const [id,key] of [['opsGroup','group'],['opsCycle','cycle'],['opsFilter','filter']])el(id).onchange=e=>{if(key==='group')bankGroup=e.target.value;else if(key==='cycle')bankCycle=e.target.value;else bankFilter=e.target.value;bankPage=0;render();};
  el('opsExport').onclick=()=>csv(data.items.map(({assets_hash,...r})=>r),'bank-usage-'+active());
  document.querySelectorAll('[data-reserve]').forEach(b=>b.onclick=()=>{const r=data.items[+b.dataset.reserve];dialog(r.reserve?'Return question to catalogue':'Move question to reserve',`<p>${safe(r.lesson)} · ${safe(r.code)}</p>`+area('reserveReason','Reason (5–500 characters)'),async()=>rpc('staff_question_reserve',{p_question:r.id,p_reserve:!r.reserve,p_reason:val('reserveReason'),p_expected_hash:r.assets_hash}));el('reserveReason').minLength=5;el('reserveReason').maxLength=500;});
  window.AdminBulk?.mount('reserve',data.items,el('view').querySelector('table'));
  pager(bankPage,data.total,p=>{bankPage=p;render();});
 }
 // Keep the requested reference and diagnosis tabs visible with daily destinations.
 if(typeof paintDashboard==='function'&&el('examList')){
  const paint=paintDashboard;paintDashboard=function(){const result=paint.apply(this,arguments);
   const primary=new Map([['daily','Today'],['formulas',ST.track?.id==='est_eng'?'Rules reference':ST.track?.id==='act2'?'Formulas & materials':'Formulas'],['finalsDiagnosis','Diagnosis'],['revision','Practice'],['mistakes','My mistakes'],['full_exam','Exams'],['overview','Progress']]);
   if(!document.querySelector('[data-view="revision"]'))primary.set('lesson_exam','Practice');
   document.querySelectorAll('.student-tabs [data-view]').forEach(b=>{const id=b.dataset.view;
    if(primary.has(id)){b.childNodes[0].textContent=primary.get(id);b.hidden=false;}
    else b.hidden=id!==DASH.view;
   });
   const select=el('studentSection');if(select)select.querySelectorAll('option').forEach(o=>{if(primary.has(o.value))o.textContent=primary.get(o.value);});
   const location=el('navigationLocation');if(location&&select)location.textContent=ST.track.name+' / '+select.selectedOptions[0].textContent;
   return result;
  };
 }
 // Accessible destinations and predictable focus, on both staff and student pages.
 const target=el('app')||el('examList');if(target){target.tabIndex=-1;const skip=document.createElement('a');skip.href='#'+target.id;skip.className='portal-skip-link';skip.textContent='Skip to main content';document.body.prepend(skip);}
})();
