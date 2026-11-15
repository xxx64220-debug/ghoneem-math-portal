'use strict';
const sb=supabase.createClient('https://wfhurjyouemahvkcfkdz.supabase.co','sb_publishable_FIUSELOTsAQaH8dQ6oF-ow_CcISJV5-',globalThis.PortalConnection?.options('https://wfhurjyouemahvkcfkdz.supabase.co'));
const $=id=>document.getElementById(id),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const mathTracks={sat:'SAT Math',est:'EST I Math',est2:'EST II Math',act2:'ACT2 Math'};
let roadmap=false, calendar=false, assignedAssessments=[], scheduleAssignments=[], scheduleVerified=false, assessmentMetadataVerified=false, roadmapTarget=null;
let progressCacheSource=null,progressCache=new Map();
let enrollmentWindows=[], enrollmentVerified=false;
let me,staff=false,groups=[],members=[],students=[],plans=[],progress=[],exams=[],progressView=false,request=0,loading=false,ready=false,editorTarget=null;
async function rows(q){const {data,error}=await q;if(error)throw Error(error.message);return data||[];}
async function pages(make,current=()=>true){
 const result=[];
 for(let offset=0;;offset+=500){
  if(!current())throw Error('Selection changed');
  const page=await rows(make().range(offset,offset+499));
  if(!current())throw Error('Selection changed');
  result.push(...page);
  if(page.length<500)return result;
 }
}
function message(s,error=false){$('message').textContent=s;$('message').className=error?'error':'';}
function selectedUsers(){const g=$('group').value;return students.filter(s=>(!g||members.some(m=>m.group_id===g&&m.user_id===s.user_id))&&(!$('student').value||s.user_id===$('student').value));}
function selectStudents(){const previous=$('student').value,g=$('group').value;const list=students.filter(s=>!g||members.some(m=>m.group_id===g&&m.user_id===s.user_id));$('student').innerHTML='<option value="">All selected students</option>'+list.map(s=>`<option value="${s.user_id}">${esc(s.full_name)}</option>`).join('');if(list.some(s=>s.user_id===previous))$('student').value=previous;}
async function load(){const token=++request;loading=true;ready=false;enrollmentWindows=[];enrollmentVerified=false;plans=[];progress=[];groups=[];scheduleAssignments=[];scheduleVerified=false;assessmentMetadataVerified=false;$('statusOverview').replaceChildren();$('todayAssignments').replaceChildren();$('planOverview').replaceChildren();$('planCoverage').replaceChildren();$('planChecks').replaceChildren();$('calendarPanel').replaceChildren();$('edit').disabled=true;$('content').replaceChildren();message('Loading…');try{const track=$('track').value;
 if(staff){const [gs,ms,es,ps]=await Promise.all([pages(()=>sb.from('groups').select('id,name,track_id,teaching_plan,target_exam_date,plan_version,course_starts_on,course_ends_on,daily_lessons').eq('track_id',track).order('id'),()=>token===request),pages(()=>sb.from('group_members').select('group_id,user_id').order('group_id').order('user_id'),()=>token===request),pages(()=>sb.from('enrollments').select('user_id').eq('track_id',track).order('user_id'),()=>token===request),pages(()=>sb.from('profiles').select('id,full_name,is_test').eq('role','student').order('id'),()=>token===request)]);if(token!==request)return;groups=gs;members=ms;students=es.map(e=>({...e,...ps.find(p=>p.id===e.user_id)})).filter(s=>s.id&&!s.is_test);const prior=$('group').value;$('group').innerHTML='<option value="">All groups</option>'+groups.map(g=>`<option value="${g.id}">${esc(g.name)}</option>`).join('');if(groups.some(g=>g.id===prior))$('group').value=prior;selectStudents();}
 if(!staff){members=await pages(()=>sb.from('group_members').select('group_id,user_id').eq('user_id',me.id).order('group_id'),()=>token===request);groups=await pages(()=>sb.from('groups').select('id,name,track_id,teaching_plan,target_exam_date,plan_version,course_starts_on,course_ends_on,daily_lessons').eq('track_id',track).order('name').order('id'),()=>token===request);if(token!==request)return;}
 const date=$('date').value;const from=new Date(date+'T12:00:00Z');from.setUTCDate(from.getUTCDate()-30);const to=new Date(date+'T12:00:00Z');to.setUTCDate(to.getUTCDate()+30);const monthStart=new Date(date.slice(0,7)+'-01T12:00:00Z'),monthEnd=new Date(Date.UTC(+date.slice(0,4),+date.slice(5,7),0,12));if(from>monthStart)from.setTime(monthStart.getTime());if(to<monthEnd)to.setTime(monthEnd.getTime());
 const [p,s]=await Promise.all([pages(()=>sb.from('student_daily_objectives').select('*').eq('track_id',track).gte('study_date',from.toISOString().slice(0,10)).lte('study_date',to.toISOString().slice(0,10)).order('study_date').order('user_id'),()=>token===request),pages(()=>sb.from('study_activity_completion').select('*').eq('track_id',track).gte('study_date',from.toISOString().slice(0,10)).lte('study_date',to.toISOString().slice(0,10)).order('study_date').order('user_id').order('activity'),()=>token===request)]);if(token!==request)return;plans=p;progress=s;assignedAssessments=[];
 const linkedIds=[...new Set(p.flatMap(plan=>['lesson','practice','retest'].map(a=>plan[a+'_exam_id'])).filter(Boolean))];
 try {
  const loaded=[];
  for(let i=0;i<linkedIds.length;i+=100)loaded.push(...await pages(()=>sb.from('exams').select('id,title,is_published,duration_seconds').in('id',linkedIds.slice(i,i+100)).order('id'),()=>token===request));
  if(token!==request)return;assignedAssessments=loaded;assessmentMetadataVerified=true;
 } catch { /* Show an explicit verification gap alongside preserved links. */ }
 try {
  const scheduled=await pages(()=>sb.from('assignments').select('id,exam_id,group_id,user_id,open_at,close_at,exams!inner(id,title,track_id,duration_seconds,is_published)').eq('exams.track_id',track).or('open_at.is.null,open_at.lte.'+to.toISOString().slice(0,10)+'T23:59:59Z').or('close_at.is.null,close_at.gte.'+from.toISOString().slice(0,10)+'T00:00:00Z').order('id'),()=>token===request);
  if(token!==request)return;scheduleAssignments=scheduled;scheduleVerified=true;
 } catch { /* The plan remains usable when schedule reads fail. */ }
 try {
  enrollmentWindows=await pages(()=>sb.from('enrollments').select('user_id,track_id,status,starts_at,ends_at').eq('track_id',track).order('user_id'),()=>token===request);
  if(token!==request)return;enrollmentVerified=true;
 } catch { /* Do not hide existing plans when access-window verification fails. */ }
 if(token!==request)return;loading=false;ready=true;render();message('Completion updates automatically after you submit the linked assessment. Reading or opening a page alone does not complete an activity.');return true;
 }catch(e){if(token===request){message('Could not load the plan: '+e.message,true);$('content').replaceChildren();}}finally{if(token===request){loading=false;$('edit').disabled=!ready;}}}
function evidence(p, activity) {
 if(progressCacheSource!==progress){progressCacheSource=progress;progressCache=new Map(progress.map(row=>[[row.user_id,row.track_id,row.study_date,row.activity].join('|'),row]));}
 return progressCache.get([p.user_id,p.track_id,p.study_date,activity].join('|'));
}
function state(p, activity) {
 return evidence(p, activity)?.status || 'unavailable';
}
const statusLabels = {
 completed: 'Completed automatically',
 in_progress: 'Started — awaiting submission',
 skipped: 'Skipped by instructor',
 pending: 'Awaiting submission',
 needs_link: 'Assessment link needed',
 unavailable: 'Progress unavailable'
};
function statusMarkup(p, activity) {
 const row = evidence(p, activity);
 const status = state(p, activity);
 const timestamp = row?.submitted_at ? new Intl.DateTimeFormat('en-GB', {
   timeZone: 'Africa/Cairo', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
 }).format(new Date(row.submitted_at)) : '';
 return '<strong class="activity-status">' + esc(statusLabels[status]) + '</strong>' +
   (timestamp ? '<small>Submitted ' + esc(timestamp) + ' · Cairo</small>' : '') +
   (status === 'needs_link' ? '<small>Your instructor needs to link an assessment to verify this activity.</small>' : '');
}
function relevant(){const ids=staff?selectedUsers().map(s=>s.user_id):[me.id];return plans.filter(p=>p.track_id===$('track').value&&ids.includes(p.user_id));}
function link(p,a){if(a==='practice'&&p.practice_source==='daily_quiz')return '/?'+new URLSearchParams({study_track:p.track_id,study_date:p.study_date,study_activity:'daily',study_group:p.practice_group_id||'00000000-0000-0000-0000-000000000000'});const id=p[a+'_exam_id'];const params=new URLSearchParams({study_track:p.track_id,study_date:p.study_date,study_activity:a==='lesson'?'practice':a==='retest'?'mistakes':p.destination,study_lesson:p.lesson});if(id)params.set('study_exam',id);return '/?'+params;}
function assignmentMarkup(p,a){
 const skipped=state(p,a)==='skipped', daily=a==='practice'&&p.practice_source==='daily_quiz';
 const id=p[a+'_exam_id'];
 if(skipped)return '<small class="optional-label">Not required for this day</small>';
 if(!id&&!daily)return '';
 const title=daily?'Daily five-question quiz':assignedAssessments.find(e=>e.id===id)?.title;
 return '<div class="assigned-detail"><strong>ASSIGNED DAILY TASK</strong>'+(title?'<span>'+esc(title)+'</span>':'')+'<small>Submit this exact assessment to complete this objective. Other quizzes on the same topic do not count automatically.</small></div>';
}
function render(){if(loading)return;if(!initialContextPending)syncPlannerLocation();renderPlanningTools();renderCoverage();const track=$('track').value;renderCoursePathway(track);$('roadmapTab').setAttribute('aria-pressed',roadmap);document.dispatchEvent(new Event('study-plan-view'));if(roadmap){$('dayTab').setAttribute('aria-pressed',false);$('progressTab').setAttribute('aria-pressed',false);const visible=visibleGroups();$('content').innerHTML='<h2>Group study roadmap</h2><p class="muted">Follow your named class plan when you also belong to an all-students group. Your dated personal objectives take priority. Choose Today objectives for assessment links and progress.</p>'+visible.map(g=>'<section class="roadmap"><h3>'+esc(g.name)+'</h3>'+(g.target_exam_date?'<p class="muted">Target: '+esc(g.target_exam_date)+'</p>':'')+(staff?'<button class="secondary" data-roadmap-edit="'+esc(g.id)+'">Edit group roadmap</button>':'')+'<div class="roadmap-text">'+esc((g.teaching_plan||'No group roadmap saved yet.').replace(/\\n/g,'\n'))+'</div></section>').join('')+(!visible.length?'<p>No group roadmap is available for this course.</p>':'');return;}const all=relevant(),day=all.filter(p=>p.study_date===$('date').value);$('dayTab').setAttribute('aria-pressed',!progressView&&!calendar);$('progressTab').setAttribute('aria-pressed',progressView);document.dispatchEvent(new Event('study-plan-view'));
 if(progressView){const counts={completed:0,in_progress:0,pending:0,skipped:0,needs_link:0,unavailable:0};all.forEach(p=>['lesson','practice','retest'].forEach(a=>counts[state(p,a)]++));$('content').innerHTML=`<h2>Study progress</h2><p class="muted">${staff?'Selected students · ':''}30 days before and after the selected date, plus the full selected month. Submitted assessments determine completion. Awaiting submission includes future work. Reading and PDF tasks need an assessment link for verification.</p><div class="summary">${Object.entries(counts).map(([k,v])=>`<div><strong>${v}</strong>${esc(statusLabels[k])}</div>`).join('')}<div><strong>${all.length}</strong>planned student-days</div></div><div class="history"><table><thead><tr><th>Date</th>${staff?'<th>Student</th>':''}<th>Objective</th><th>Lesson</th><th>Practice</th><th>Retest</th></tr></thead><tbody>${all.map(p=>`<tr><td>${esc(p.study_date)}</td>${staff?`<td>${esc(students.find(s=>s.user_id===p.user_id)?.full_name||'Student')}</td>`:''}<td>${esc(p.title)}</td>${['lesson','practice','retest'].map(a=>`<td>${statusMarkup(p,a)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>${!all.length?'<p>No objectives assigned in this date range.</p>':''}`;return;}
 const missing=staff?selectedUsers().filter(s=>!day.some(p=>p.user_id===s.user_id)).length:0;
 $('content').innerHTML=(missing?`<p class="muted">${missing} selected student(s) have no plan on this date. Unassigned work is not counted as pending.</p>`:'')+(day.length?day.map((p,i)=>`<section><div class="dayhead"><div><div class="eyebrow">${staff?esc(students.find(s=>s.user_id===p.user_id)?.full_name||'Student'):'YOUR DAILY FOCUS'} · ${esc(p.study_date)}</div><h2>${esc(p.title)}</h2><p class="muted">${esc((p.instructions||'').split('\n').find(line=>line.startsWith('Group: ')||line.startsWith('Personal plan: '))||'Personal objective · no group recorded')}</p><span class="muted">${esc(p.time_budget)}</span></div><span class="badge">${p.calculator_allowed?'Calculator allowed':'Check activity calculator rules'}</span></div><div class="cards">${['lesson','practice','retest'].map((a,j)=>`<article class="card ${state(p,a)}"><span class="step">0${j+1}</span>${assignmentMarkup(p,a)}<h3>${a==='lesson'?'Learn & review':a==='practice'?'Focused practice':'Retest & reflect'}</h3><b>${a==='lesson'?esc(p.lesson||'Recommended lesson'):a==='practice'?'Apply the lesson':'Check your understanding'}</b><p>${esc(a==='lesson'?p.instructions:a==='practice'?(p.practice_note||'Practise this lesson and review each mistake.'):(p.retest_note||'Revisit your mistakes and explain the corrected method.'))}</p><small>${p.calculator_allowed?'Calculator allowed':'Follow linked activity rules'}</small><a class="${state(p,a)!=='skipped'&&(p[a+'_exam_id']||(a==='practice'&&p.practice_source==='daily_quiz'))?'assigned-action':''}" href="${esc(link(p,a))}">${a==='practice'&&p.practice_source==='daily_quiz'?'Open assigned Daily Quiz':p[a+'_exam_id']?'Open assigned daily assessment':a==='lesson'?'Open lesson practice':'Open recommended practice'} →</a>${statusMarkup(p,a)}</article>`).join('')}</div></section>`).join(''):'<div class="empty"><h2>No objectives assigned for this day</h2><p>Your existing quizzes and exams are still available in the portal.</p><a href="/">Open portal →</a></div>');
}
// Dates stay in Cairo; date-only calendar arithmetic uses UTC to avoid device-timezone shifts.
const cairoDate=value=>new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(value));
const dateLabel=value=>new Intl.DateTimeFormat('en-GB',{timeZone:'UTC',day:'numeric',month:'short',year:'numeric'}).format(new Date(value+'T12:00:00Z'));
const windowLabel=value=>value?new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Cairo',day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'}).format(new Date(value)):'No limit';
function visibleGroups(){
 return groups.filter(g=>g.track_id===$('track').value&&(!staff||!$('group').value||g.id===$('group').value)&&
  (!staff?members.some(m=>m.user_id===me.id&&m.group_id===g.id):!$('student').value||members.some(m=>m.user_id===$('student').value&&m.group_id===g.id)));
}
function appliesTo(a,user){return a.user_id===user||(!a.user_id&&a.group_id&&members.some(m=>m.user_id===user&&m.group_id===a.group_id));}
function selectedAssignments(){const ids=staff?selectedUsers().map(u=>u.user_id):[me.id];return scheduleAssignments.filter(a=>ids.some(id=>appliesTo(a,id)));}
function dayAssignments(date){return selectedAssignments().filter(a=>a.open_at&&cairoDate(a.open_at)===date);}
function dayCounts(date){const counts={completed:0,skipped:0,pending:0,unverified:0};for(const p of relevant().filter(p=>p.study_date===date))for(const a of ['lesson','practice','retest']){const s=state(p,a);counts[s==='completed'?'completed':s==='skipped'?'skipped':['pending','in_progress'].includes(s)?'pending':'unverified']++;}return counts;}
// A reference recurrence, checked in production 8 Nov 2026. Dated assignments remain authoritative.
const alexSchedule={group:'a8509c9b-fe47-4ed7-90c7-cde7c27904cd',start:'2026-11-03',weekday:2};
function expectedAlex(date){return date>=alexSchedule.start&&new Date(date+'T12:00:00Z').getUTCDay()===alexSchedule.weekday&&visibleGroups().some(g=>g.id===alexSchedule.group);}
function exactAlex(date){return dayAssignments(date).some(a=>a.group_id===alexSchedule.group&&/Tuesday Algebra/.test(a.exams?.title||''));}
function planIssues(day){
 const issues=[],seen=new Set();const add=(text,kind='review')=>{if(!seen.has(text)){seen.add(text);issues.push({text,kind});}};
 if(!scheduleVerified)add('Assignment windows could not be verified. Existing activity links are still available.','unverified');
 if(!assessmentMetadataVerified)add('Assessment details could not be verified.','unverified');
 const date=$('date').value;
 if(!enrollmentVerified)add('Course access dates could not be verified. Opening an objective does not grant access.','unverified');
 else {
  const ids=staff?selectedUsers().map(s=>s.user_id):[me.id];
  for(const id of ids){
   const who=staff?(students.find(s=>s.user_id===id)?.full_name||'Student')+': ':'';
   const e=enrollmentWindows.find(e=>e.user_id===id&&e.track_id===$('track').value);
   if(!e||e.status!=='active')add(who+'Course enrolment is not active. Contact your instructor about access.');
   else if(e.starts_at&&cairoDate(e.starts_at)>date)add(who+'Course access begins '+windowLabel(e.starts_at)+' Cairo, after this study date.');
   else if(e.ends_at&&cairoDate(e.ends_at)<=date)add(who+'Course access ends '+windowLabel(e.ends_at)+' Cairo. Work on this date may be unavailable; contact your instructor.');
  }
 }
 for(const p of day){const who=staff?(students.find(s=>s.user_id===p.user_id)?.full_name||'Student')+': ':'';
  for(const activity of ['lesson','practice','retest']){
   if(state(p,activity)==='skipped')continue;
   const exam=p[activity+'_exam_id'];
   if(activity==='practice'&&p.practice_source==='daily_quiz')continue;
   if(!exam){add(who+activity+' needs an assessment link to verify completion.','missing_link');continue;}
   if(assignedAssessments.some(e=>e.id===exam&&e.is_published===false))add(who+activity+' links to an unpublished assessment.');
   if(assessmentMetadataVerified&&!assignedAssessments.some(e=>e.id===exam))add(who+activity+' assessment is missing or not visible.','unverified');
   if(scheduleVerified){const matching=scheduleAssignments.filter(a=>a.exam_id===exam&&appliesTo(a,p.user_id));
    if(!matching.length)add(who+activity+' has no visible assignment in this date range. Linking it does not grant access.');
    else if(!matching.some(a=>(!a.open_at||cairoDate(a.open_at)<=date)&&(!a.close_at||cairoDate(a.close_at)>=date)))add(who+activity+' is outside its assignment window on this study date.');
   }
  }
 }
 if(!day.length&&visibleGroups().some(g=>g.target_exam_date&&date>=today()&&date<g.target_exam_date))add('No daily objective is assigned for this study date. The group roadmap does not automatically create a dated assessment.','unverified');
 const targetGroups=visibleGroups().filter(g=>g.target_exam_date===date);
 if(day.length&&targetGroups.length)add('Portal objectives fall on the target exam day. Review the workload before publishing.');
 // Availability overlap is a possible conflict, not proof of a lesson-time clash.
 // Broad multi-day availability is not a scheduled session. Flag only narrow start windows.
 const timed=selectedAssignments().filter(a=>a.open_at&&a.close_at&&cairoDate(a.open_at)<=date&&cairoDate(a.close_at)>=date&&new Date(a.close_at)>new Date(a.open_at)&&new Date(a.close_at)-new Date(a.open_at)<=6*3600000);
 const users=staff?selectedUsers().map(u=>u.user_id):[me.id];
 for(let i=0;i<timed.length;i++)for(let j=i+1;j<timed.length;j++){
  const a=timed[i],b=timed[j];if(a.exam_id===b.exam_id)continue;
  if(new Date(a.open_at)<new Date(b.close_at)&&new Date(b.open_at)<new Date(a.close_at)&&users.some(id=>appliesTo(a,id)&&appliesTo(b,id)))add('Possible schedule conflict: “'+(a.exams?.title||'Assessment')+'” and “'+(b.exams?.title||'Assessment')+'” have overlapping availability for the same student. Confirm the intended start times.','conflict');
 }
 if(expectedAlex(date)&&!exactAlex(date))add('Alex Tuesday algebra is expected at 13:10–13:30 Cairo. A dated assessment is not yet visible; its link and availability are unverified.','unverified');
 return issues;
}
// Targets recorded on personal objectives take priority for that student only.
function objectiveTarget(p){const value=(p.instructions||'').match(/^Target exam: (\d{4}-\d{2}-\d{2})$/m)?.[1];return value&&Number.isFinite(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value?value:null;}
function preparationTargets(){
 const personal=[...new Set(relevant().map(objectiveTarget).filter(Boolean))];
 return [...new Set([...personal,...(personal.length&&(!staff||$('student').value)?[]:visibleGroups().map(g=>g.target_exam_date).filter(Boolean))])].sort();
}
function renderCoursePathway(track){
 $('revisionLink').hidden=!mathTracks[track];
 const targets=preparationTargets();
 $('satPathwayTitle').textContent=(mathTracks[track]||'Course')+' preparation'+(targets.length===1?' · '+dateLabel(targets[0]):'');
 const labels={practice:'Topic practice',full_exam:'Assigned exams',mistakes:'Mistakes & revision'};
 $('revisionLink').querySelectorAll('.pathway-links a').forEach(a=>{const url=new URL(a.href,location.href),activity=url.searchParams.get('study_activity');url.searchParams.set('study_track',track);a.href=url.pathname+url.search;a.textContent=labels[activity]+' →';});
 $('earlierSat').hidden=track!=='sat';
 $('estRevision').hidden=!['est','est2'].includes(track);
 if(['est','est2'].includes(track)){$('estRevisionLink').href='/est-revision.html?track='+track;$('estRevisionLink').textContent='December '+mathTracks[track]+' revision · weekly guide & topics →';}
}
function renderPlanningTools(){
 const date=$('date').value,day=relevant().filter(p=>p.study_date===date),vg=visibleGroups();
 $('calendarTab').setAttribute('aria-pressed',calendar);$('calendarPanel').hidden=!calendar;
 const targets=preparationTargets();
 const next=targets.find(d=>d>=today())||targets.at(-1);
 const remaining=next?Math.round((Date.parse(next+'T12:00:00Z')-Date.parse(today()+'T12:00:00Z'))/86400000):null;
 const counts=dayCounts(date);
 $('planOverview').innerHTML='<p class="group-context">'+(vg.length?'Portal groups: '+vg.map(g=>esc(g.name)).join(' · '):'No group membership is visible for this course.')+'</p><div class="overview-strip"><div><span class="eyebrow">EXAM PREPARATION</span><strong>'+(next?esc(dateLabel(next)):'Target date not set')+'</strong><small>'+(next?(remaining>=0?remaining+' days to exam':'Target date has passed'):'No personal or group exam date is recorded')+'</small></div><div><strong>'+day.length+'</strong><small>planned '+(staff?'student-days':'day')+' · '+esc(dateLabel(date))+'</small></div><div><strong>'+counts.completed+' <span>/ '+(counts.completed+counts.pending+counts.unverified)+'</span></strong><small>activities completed · '+counts.skipped+' skipped</small></div></div>'+(targets.length>1?'<p class="muted">Selected groups have different targets: '+targets.map(dateLabel).map(esc).join(' · ')+'</p>':'');
 const issues=planIssues(day);
 $('planChecks').innerHTML=(progressView||roadmap)?'':'<details class="plan-checks"><summary>'+issues.length+' item'+(issues.length===1?'':'s')+' to review · '+esc(dateLabel(date))+'</summary>'+(issues.length?'<ul>'+issues.map(i=>'<li><span class="flag '+i.kind+'">'+({unverified:'Unverified',missing_link:'Missing link',conflict:'Possible schedule conflict'}[i.kind]||'Review')+'</span> '+esc(i.text)+'</li>').join('')+'</ul>':'<p>No missing links or date conflicts found in the available records.</p>')+'<small>Checks cover this course’s visible assignments. Lesson times, other courses and external calendars are not verified here.</small></details>';
 if(calendar)renderCalendar();
}
function renderCalendar(){
 const selected=$('date').value,y=+selected.slice(0,4),m=+selected.slice(5,7)-1;
 const first=new Date(Date.UTC(y,m,1)),days=new Date(Date.UTC(y,m+1,0)).getUTCDate(),pad=(first.getUTCDay()+6)%7;
 const title=new Intl.DateTimeFormat('en-GB',{timeZone:'UTC',month:'long',year:'numeric'}).format(first);
 const plansByDate=new Map();for(const p of relevant()){if(!plansByDate.has(p.study_date))plansByDate.set(p.study_date,[]);plansByDate.get(p.study_date).push(p);}
 let cells='<span class="calendar-pad" aria-hidden="true"></span>'.repeat(pad);
 for(let n=1;n<=days;n++){
  const date=[y,String(m+1).padStart(2,'0'),String(n).padStart(2,'0')].join('-'),ps=plansByDate.get(date)||[],counts=dayCounts(date),assigned=dayAssignments(date),target=preparationTargets().includes(date),weekly=expectedAlex(date);
  const label=dateLabel(date)+', '+ps.length+' planned student-days, '+counts.completed+' completed, '+counts.pending+' pending, '+counts.skipped+' skipped'+(target?', target exam day':'')+(weekly?', Alex algebra assessment expected':'');
  cells+='<button class="calendar-day '+(date===selected?'selected ':'')+(date===today()?'is-today ':'')+(target?'exam-day':'')+'" data-calendar-date="'+date+'" aria-label="'+esc(label)+'" aria-pressed="'+(date===selected)+'"><span class="calendar-number">'+n+(date===today()?'<small>Today</small>':'')+'</span>'+(target?'<span class="calendar-tag target">Exam day</span>':'')+(ps.length?'<span class="calendar-topic">'+esc(ps[0].lesson||ps[0].title)+'</span><small>'+ps.length+(staff?' student-days':' objective')+'</small>':'<small class="no-plan">No objectives</small>')+(weekly?'<span class="calendar-tag weekly">Algebra · 13:10'+(!exactAlex(date)?' *':'')+'</span>':assigned.length?'<span class="calendar-tag">'+assigned.length+' opening'+(assigned.length===1?'':'s')+'</span>':'')+'<span class="calendar-dots">'+(counts.completed?'<i class="done"></i> '+counts.completed+' ':'')+(counts.pending?'<i class="waiting"></i> '+counts.pending+' ':'')+(counts.skipped?'<i class="skip"></i> '+counts.skipped+' ':'')+(counts.unverified?'<i class="unknown"></i> '+counts.unverified:'')+'</span></button>';
 }
 const date=$('date').value,scheduled=dayAssignments(date);
 $('calendarPanel').innerHTML='<div class="calendar-head"><div><div class="eyebrow">YOUR STUDY CALENDAR</div><h2>'+title+'</h2></div><div class="actions"><button class="secondary" id="previousMonth" aria-label="Previous month">←</button><button class="secondary" id="nextMonth" aria-label="Next month">→</button></div></div><div class="calendar-weekdays" aria-hidden="true">'+['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map(x=>'<span>'+x+'</span>').join('')+'</div><div class="calendar-grid">'+cells+'</div><p class="calendar-legend"><span><i class="done"></i> Completed</span><span><i class="waiting"></i> Pending / started</span><span><i class="skip"></i> Skipped</span><span><i class="unknown"></i> Unverified</span></p>'+(visibleGroups().some(g=>g.id===alexSchedule.group)?'<p class="muted">Alex algebra: Tuesdays, 13:10–13:30 Cairo · 10 questions, 20 minutes. Recurrence checked 8 Nov 2026. * Dated assessment not yet visible; confirm before class. Actual assignment windows below take priority.</p>':'')+'<section class="calendar-agenda"><div class="eyebrow">SELECTED DAY · CAIRO TIME</div><h2>'+esc(dateLabel(date))+'</h2>'+(scheduled.length?scheduled.map(a=>'<div class="agenda-row"><div><strong>'+esc(a.exams?.title||'Assigned assessment')+'</strong><small>Opens '+esc(windowLabel(a.open_at))+' · New-start cutoff '+esc(windowLabel(a.close_at))+' · '+Math.round((a.exams?.duration_seconds||0)/60)+' minutes</small></div><a href="'+esc('/?'+new URLSearchParams({study_track:$('track').value,study_exam:a.exam_id}))+'">Open assessment →</a></div>').join(''):'<p class="muted">'+(scheduleVerified?'No assessment opening is recorded for this day.':'Assessment openings are unverified.')+'</p>')+'</section>';
 $('previousMonth').onclick=()=>changeMonth(-1);$('nextMonth').onclick=()=>changeMonth(1);
 $('calendarPanel').querySelectorAll('[data-calendar-date]').forEach(b=>b.onclick=()=>{$('date').value=b.dataset.calendarDate;followToday=b.dataset.calendarDate===today();render();});
}
async function changeMonth(delta){const date=new Date($('date').value+'T12:00:00Z');date.setUTCDate(1);date.setUTCMonth(date.getUTCMonth()+delta);$('date').value=date.toISOString().slice(0,10);followToday=false;await load();}
async function editRoadmap(id){
 if(!staff||loading||!ready)return;
 const g=groups.find(g=>g.id===id);if(!g)return;
 roadmapTarget={...g};$('roadmapTarget').textContent=g.name;
 const f=$('roadmapForm').elements;f.target_exam_date.value=g.target_exam_date||'';f.teaching_plan.value=(g.teaching_plan||'').replace(/\\n/g,'\n');$('roadmapError').textContent='';$('roadmapEditor').showModal();
}
$('content').addEventListener('click',event=>{const button=event.target.closest('[data-roadmap-edit]');if(button)editRoadmap(button.dataset.roadmapEdit);});
$('cancelRoadmap').onclick=()=>{roadmapTarget=null;$('roadmapEditor').close();};
$('roadmapForm').onsubmit=async event=>{
 event.preventDefault();$('saveRoadmap').disabled=true;
 try{
  if(!staff||!roadmapTarget)throw Error('Select a group again.');
  const g=roadmapTarget,f=event.target.elements;
  const {error}=await sb.rpc('staff_save_group_plan',{p_group:g.id,p_expected_version:g.plan_version,p_data:{teaching_plan:f.teaching_plan.value.trim(),target_exam_date:f.target_exam_date.value||null,course_starts_on:g.course_starts_on,course_ends_on:g.course_ends_on,daily_lessons:g.daily_lessons||[]}});
  if(error)throw Error(error.message==='plan_changed_refresh'?'This group plan changed elsewhere. Close and reload before editing.':error.message);
  roadmapTarget=null;$('roadmapEditor').close();if(await load())message('Group roadmap published.');
 }catch(e){$('roadmapError').textContent='Not published: '+e.message;}finally{$('saveRoadmap').disabled=false;}
};

async function edit(){if(!staff||loading||!ready)return;const token=request,track=$('track').value,date=$('date').value;try{const users=selectedUsers();if(!users.length)throw Error('Select at least one student.');const available=await pages(()=>sb.from('exams').select('id,title').eq('track_id',track).eq('is_published',true).order('title').order('id'),()=>token===request);if(token!==request)return;exams=available;editorTarget={track,date,users:users.map(s=>s.user_id)};const form=$('planForm');form.reset();form.elements.practice_group_id.innerHTML='<option value="">Earlier course quiz</option>'+groups.map(g=>`<option value="${g.id}">${esc(g.name)}</option>`).join('');const options='<option value="">No linked assessment — completion cannot be verified</option>'+exams.map(e=>`<option value="${e.id}">${esc(e.title)}</option>`).join('');form.elements.lesson_exam_id.innerHTML=options;form.elements.practice_exam_id.innerHTML=options;form.elements.retest_exam_id.innerHTML=options;const p=users.length===1?plans.find(p=>p.user_id===users[0].user_id&&p.study_date===$('date').value):null;if(p)for(const a of ['lesson','practice','retest']){const id=p[a+'_exam_id'];if(id&&!exams.some(e=>e.id===id))form.elements[a+'_exam_id'].add(new Option('Existing link — unavailable / unverified',id));}if(p)for(const key of ['title','instructions','time_budget','lesson','practice_note','retest_note','lesson_exam_id','practice_exam_id','retest_exam_id','destination'])form.elements[key].value=p[key]||'';if(p){form.elements.calculator_allowed.checked=p.calculator_allowed;form.elements.practice_source.value=p.practice_source||'exam';form.elements.practice_group_id.value=p.practice_group_id||'';for(const a of ['lesson','practice','retest'])form.elements['skip_'+a].checked=(p.skipped_activities||[]).includes(a);}syncPracticeFields();const replacing=users.length>1&&plans.some(p=>p.study_date===date&&users.some(u=>u.user_id===p.user_id));editorTarget.replacing=replacing;$('replaceLabel').hidden=!replacing;form.elements.replace_existing.checked=false;$('target').textContent=`${$('date').value} · ${users.length===1?users[0].full_name:users.length+' students'}${users.length>1?' · Replaces objectives for this date, completion will be checked against the updated assessment links.':''}`;$('saveError').textContent='';$('editor').showModal();}catch(e){if(token===request)message(e.message,true);}}
$('planForm').onsubmit=async e=>{e.preventDefault();$('save').disabled=true;try{if(!staff||!editorTarget)throw Error('Reopen the editor to select students.');const target=editorTarget;if(target.replacing&&!e.target.elements.replace_existing.checked)throw Error('Review and acknowledge replacement of the existing personal objectives.');const f=e.target.elements,base={track_id:target.track,study_date:target.date,calculator_allowed:f.calculator_allowed.checked,practice_source:f.practice_source.value,practice_group_id:f.practice_source.value==='daily_quiz'?(f.practice_group_id.value||null):null,skipped_activities:['lesson','practice','retest'].filter(a=>f['skip_'+a].checked)};for(const k of ['title','instructions','time_budget','lesson','practice_note','retest_note','destination'])base[k]=f[k].value.trim();for(const k of ['lesson_exam_id','practice_exam_id','retest_exam_id'])base[k]=f[k].value||null;if(base.practice_source==='daily_quiz'){base.practice_exam_id=null;if(base.practice_group_id&&target.users.some(user=>!members.some(m=>m.user_id===user&&m.group_id===base.practice_group_id)))throw Error('Every selected student must belong to the Daily Quiz group.');}if(!base.title||!base.instructions||!base.time_budget)throw Error('Title, instructions and time budget are required.');const data=target.users.map(user_id=>({...base,user_id}));const saved=await rows(sb.from('student_daily_objectives').upsert(data,{onConflict:'user_id,study_date,track_id'}).select());if(saved.length!==data.length)throw Error('Not all updates were confirmed. Reload before retrying.');editorTarget=null;$('editor').close();const refreshed=await load();if(refreshed)message(`Objectives saved for ${data.length} student(s).`);}catch(e){$('saveError').textContent='Not saved: '+e.message;}finally{$('save').disabled=false;}};
function syncPracticeFields(){const f=$('planForm').elements,quiz=f.practice_source.value==='daily_quiz';f.practice_group_id.closest('label').hidden=!quiz;f.practice_exam_id.closest('label').hidden=quiz;}
$('planForm').elements.practice_source.onchange=syncPracticeFields;
$('cancel').onclick=()=>{editorTarget=null;$('editor').close();};$('edit').onclick=edit;$('track').onchange=()=>{$('group').value='';$('student').value='';load();};$('group').onchange=()=>{selectStudents();render();};$('student').onchange=render;$('date').onchange=()=>{followToday=$('date').value===today();if($('date').value)load();};$('today').onclick=()=>{followToday=true;$('date').value=today();roadmap=false;progressView=false;calendar=false;load();};$('dayTab').onclick=()=>{roadmap=false;progressView=false;calendar=false;render();};$('progressTab').onclick=()=>{roadmap=false;progressView=true;calendar=false;load();};

$('roadmapTab').onclick=()=>{roadmap=true;progressView=false;calendar=false;render();};
$('calendarTab').onclick=()=>{calendar=true;roadmap=false;progressView=false;render();};
let followToday=true,initialContextPending=true;
function refreshAfterReturn() {
 if(followToday&&$('date').value!==today())$('date').value=today();
 if (me && !loading && !$('editor').open && !$('roadmapEditor').open && document.visibilityState === 'visible') void load();
}
window.addEventListener('pageshow', event => { if (event.persisted) refreshAfterReturn(); });
document.addEventListener('visibilitychange', refreshAfterReturn);

setInterval(()=>{if(me&&followToday&&$('date').value!==today())refreshAfterReturn();},30000);


function syncPlannerLocation(){
 const params=new URLSearchParams(location.search);params.set('track',$('track').value);
 params.set('view',roadmap?'roadmap':progressView?'progress':calendar?'calendar':'today');
 if(followToday)params.delete('date');else if($('date').value)params.set('date',$('date').value);
 for(const key of ['group','student']){const value=staff?$(key).value:'';if(value)params.set(key,value);else params.delete(key);}
 const next=location.pathname+'?'+params+location.hash;
 if(next===location.pathname+location.search+location.hash)return;
 // URL persistence is optional; a browser/host History failure must not hide the plan.
 try{window.history.replaceState(window.history.state,'',next);}catch(error){console.warn('Planner URL could not be updated.',error);}
}
function renderCoverage(){
 const all=relevant(),date=$('date').value;
 const users=staff?selectedUsers():[{user_id:me.id,full_name:'Your plan'}];
 const end=new Date(date+'T12:00:00Z');end.setUTCDate(end.getUTCDate()+6);const endDate=end.toISOString().slice(0,10);
 const rows=users.map(user=>{
  const own=all.filter(p=>p.user_id===user.user_id),upcoming=own.filter(p=>p.study_date>=date).sort((a,b)=>a.study_date.localeCompare(b.study_date));
  const personal=[...new Set(own.map(objectiveTarget).filter(Boolean))];
  const targets=personal.length?personal:groups.filter(g=>g.track_id===$('track').value&&members.some(m=>m.user_id===user.user_id&&m.group_id===g.id)).map(g=>g.target_exam_date).filter(Boolean);
  const target=[...new Set(targets)].sort().find(d=>d>=date),limit=target&&target<=endDate?target:endDate;
  const expected=[];for(let d=new Date(date+'T12:00:00Z');d.toISOString().slice(0,10)<=limit;d.setUTCDate(d.getUTCDate()+1)){const key=d.toISOString().slice(0,10);if(key!==target)expected.push(key);}
  const missing=expected.filter(day=>!own.some(p=>p.study_date===day));
  const params=new URLSearchParams({track:$('track').value,student:user.user_id,date:missing[0]||date,view:'today'});if($('group').value)params.set('group',$('group').value);
  return '<tr><td>'+esc(user.full_name||'Student')+'</td><td>'+esc(target?dateLabel(target):'Target unverified')+'</td><td>'+esc(upcoming.length?dateLabel(upcoming[upcoming.length-1].study_date):'No upcoming objectives')+'</td><td>'+(missing.length?'<a href="/study-plan.html?'+esc(params)+'">'+missing.length+' unplanned date'+(missing.length===1?'':'s')+' · review →</a>':'Planned')+'</td></tr>';
 });
 $('planCoverage').innerHTML='<details class="coverage-check"><summary>Plan coverage · '+users.length+' '+(staff?'selected students':'student')+'</summary><p class="muted">Unplanned dates in the next seven days may be intentional rest days. They are not pending work. Last planned date reflects the loaded calendar range; later work may exist outside it.</p><div class="history"><table><thead><tr><th>Student</th><th>Target exam</th><th>Last planned date in range</th><th>Next seven days</th></tr></thead><tbody>'+rows.join('')+'</tbody></table></div></details>';
}

async function boot(){try{const {data:{user},error}=await sb.auth.getUser();if(error||!user){message('Sign in to the portal to view your daily study plan.');window.PortalReturn?.offer($('message'));return;}me=user;
 PortalDevices.configure({sb,fnBase:'https://wfhurjyouemahvkcfkdz.supabase.co/functions/v1',key:'sb_publishable_FIUSELOTsAQaH8dQ6oF-ow_CcISJV5-',resume:boot});if(!await PortalDevices.ensure())return;
 const profile=(await rows(sb.from('profiles').select('role').eq('id',me.id)))[0];if(!profile)throw Error('Your account is not available.');staff=['admin','instructor'].includes(profile.role);for(const id of ['groupLabel','studentLabel','edit'])$(id).hidden=!staff;if(staff){$('back').href='/admin.html';$('back').textContent='← Instructor console';}else{const enrolled=await rows(sb.from('enrollments').select('track_id').eq('user_id',me.id).in('track_id',Object.keys(mathTracks)));$('track').innerHTML=enrolled.map(e=>`<option value="${e.track_id}">${mathTracks[e.track_id]}</option>`).join('');if(!enrolled.length)throw Error('No mathematics course is assigned.');}
 const context=new URLSearchParams(location.search);const selectedTrack=context.get('track');if([...$('track').options].some(o=>o.value===selectedTrack))$('track').value=selectedTrack;const requestedDate=context.get('date');$('date').value=/^\d{4}-\d{2}-\d{2}$/.test(requestedDate||'')?requestedDate:today();followToday=$('date').value===today();calendar=context.get('view')==='calendar';roadmap=context.get('view')==='roadmap';progressView=context.get('view')==='progress';$('workspace').hidden=false;await load();if(staff&&ready){const group=context.get('group'),student=context.get('student');if(groups.some(g=>g.id===group))$('group').value=group;selectStudents();if([...$('student').options].some(o=>o.value===student))$('student').value=student;render();}initialContextPending=false;syncPlannerLocation();}catch(e){message(e.message,true);}}boot();
