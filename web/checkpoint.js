/* Unpublished integration. Assessment data is read through existing portal permissions. */
(()=>{
 'use strict';
 const api='https://wfhurjyouemahvkcfkdz.supabase.co',key='sb_publishable_FIUSELOTsAQaH8dQ6oF-ow_CcISJV5-';
 const sb=supabase.createClient(api,key,globalThis.PortalConnection?.options(api)),$=id=>document.getElementById(id),C=window.CheckpointCore;
 const tracks={sat:'SAT Math',est:'EST I Math',est2:'EST II Math',act2:'ACT2 Math'};
 const activities={lesson:'Lesson',practice:'Practice',retest:'Retest'};
 const statusLabels={completed:'Completed automatically',skipped:'Skipped by instructor',pending:'Awaiting submission',in_progress:'Started — awaiting submission',needs_link:'Assessment link needed',unavailable:'Progress unavailable'};
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 let run=0,attemptRequest=0,clock,context,viewer,staff=false,students=[],groups=[],members=[],rosterReady=false;
 async function rows(query){const {data,error}=await query;if(error)throw Error('Portal data could not be verified. Please refresh.');return data||[];}
 async function pages(make,token=run){const all=[];for(let start=0;;start+=500){if(start>=10000)throw Error('This check exceeds 10,000 records. Narrow the selection; verification is incomplete.');if(token!==run)throw Error('Selection changed.');const page=await rows(make().range(start,start+499));if(token!==run)throw Error('Selection changed.');all.push(...page);if(page.length<500)return all;}}
 function activityLink(p,a){
  if(a==='practice'&&p.practice_source==='daily_quiz')return '/?'+new URLSearchParams({study_track:p.track_id,study_date:p.study_date,study_activity:'daily',study_group:p.practice_group_id||'00000000-0000-0000-0000-000000000000'});
  const id=p[a+'_exam_id'];return id?'/?'+new URLSearchParams({study_track:p.track_id,study_date:p.study_date,study_activity:'full_exam',study_exam:id}):null;
 }
 function selectionParams(user=$('student').value){const p=new URLSearchParams({track:$('course').value,date:$('checkpointDate').value,mode:$('sourceMode').value});if(staff){if($('group').value)p.set('group',$('group').value);if(user)p.set('student',user);}return p;}
 function planLink(date,user){const p=selectionParams(user);p.set('date',date);return '/study-plan.html?'+p;}
 function historyLink(){return '/?'+new URLSearchParams({study_track:context.track,study_activity:'history'});}
 function clearAssessment(){clearInterval(clock);attemptRequest++;for(const id of ['plan','budget','results','corrections','priorities','audit'])$(id).replaceChildren();$('audit').hidden=true;}
 function clear(){clearAssessment();context=null;$('checkpoint').hidden=true;$('overview').hidden=true;$('overview').replaceChildren();$('selection').replaceChildren();$('next').replaceChildren();}
 function selectedStudents(){const g=$('group').value;return students.filter(s=>!g||members.some(m=>m.group_id===g&&m.user_id===s.user_id));}
 function renderStudents(wanted=''){
  const list=selectedStudents();$('student').innerHTML='<option value="">Group overview</option>'+list.map(s=>'<option value="'+esc(s.user_id)+'">'+esc(s.full_name||'Student')+'</option>').join('');
  if(list.some(s=>s.user_id===wanted))$('student').value=wanted;
 }
 async function boot(){
  const token=++run;clear();rosterReady=false;$('scope').hidden=true;$('message').textContent='Checking your portal access…';
  try{
   const {data:{user},error}=await sb.auth.getUser();if(error||!user){window.PortalReturn?.offer($('message'));throw Error('Sign in to the portal to open Progress & corrections.');}if(token!==run)return;
   PortalDevices.configure({sb,fnBase:api+'/functions/v1',key,resume:boot});if(!await PortalDevices.ensure())return;
   const profile=(await rows(sb.from('profiles').select('role').eq('id',user.id)))[0];if(token!==run)return;
   if(!profile||!['student','instructor','admin'].includes(profile.role))throw Error('This account does not have a checkpoint workspace.');
   viewer=user.id;staff=['instructor','admin'].includes(profile.role);document.body.dataset.portalRole=staff?'staff':'student';document.dispatchEvent(new Event('portal-context'));
   const enrolled=staff?Object.keys(tracks):(await rows(sb.from('enrollments').select('track_id').eq('user_id',viewer).in('track_id',Object.keys(tracks)))).map(e=>e.track_id);
   if(token!==run)return;const allowed=[...new Set(enrolled)].filter(t=>tracks[t]);if(!allowed.length)throw Error('No mathematics course is assigned.');
   $('course').innerHTML=allowed.map(t=>'<option value="'+t+'">'+tracks[t]+'</option>').join('');
   const params=new URLSearchParams(location.search),track=params.get('track');if(allowed.includes(track))$('course').value=track;
   const date=params.get('date');$('checkpointDate').value=C.validDate(date)?date:C.cairoDate();$('sourceMode').value=params.get('mode')==='objectives'||(!params.has('mode')&&params.has('date'))?'objectives':'assessments';
   $('groupLabel').hidden=$('studentLabel').hidden=!staff;$('scope').hidden=false;
   await loadRoster(staff?params.get('group')||'':'',staff?params.get('student')||'':'');
  }catch(e){if(token===run){clear();$('message').textContent=e.message;}}
 }
 async function loadRoster(wantedGroup='',wantedStudent=''){
  const token=++run;clear();rosterReady=false;students=[];groups=[];members=[];$('group').innerHTML='<option value="">All groups</option>';$('student').innerHTML='<option value="">Group overview</option>';
  $('message').textContent='Loading available students…';const track=$('course').value;
  try{
   if(staff){
    const [gs,ms,es,ps]=await Promise.all([
     pages(()=>sb.from('groups').select('id,name').eq('track_id',track).order('id'),token),
     pages(()=>sb.from('group_members').select('group_id,user_id').order('group_id').order('user_id'),token),
     pages(()=>sb.from('enrollments').select('user_id').eq('track_id',track).order('user_id'),token),
     pages(()=>sb.from('profiles').select('id,full_name,is_test').eq('role','student').order('id'),token)
    ]);if(token!==run)return;groups=gs;members=ms;
    students=[...new Set(es.map(e=>e.user_id))].map(id=>{const p=ps.find(p=>p.id===id);return p&&!p.is_test?{user_id:id,full_name:p.full_name}:null;}).filter(Boolean);
    $('group').innerHTML='<option value="">All groups</option>'+groups.map(g=>'<option value="'+esc(g.id)+'">'+esc(g.name)+'</option>').join('');
    if(wantedGroup&&!groups.some(g=>g.id===wantedGroup))throw Error('The requested group is unavailable. Select an accessible group.');
    $('group').value=wantedGroup;renderStudents(wantedStudent);
    if(wantedStudent&&!selectedStudents().some(s=>s.user_id===wantedStudent))throw Error('The requested student is unavailable in this course or group. Select an accessible student.');
   }else{students=[{user_id:viewer,full_name:'Your checkpoint'}];members=await pages(()=>sb.from('group_members').select('group_id,user_id').eq('user_id',viewer).order('group_id'),token);}
   if(token!==run)return;rosterReady=true;await loadSelection();
  }catch(e){if(token===run){clear();rosterReady=true;$('message').textContent=e.message;}}
 }
 async function readScope(table,columns,ids,track,date,end,token){
  const result=[];for(let i=0;i<ids.length;i+=100)result.push(...await pages(()=>{
   let q=sb.from(table).select(columns).eq('track_id',track);q=ids.length===1?q.eq('user_id',ids[0]):q.in('user_id',ids.slice(i,i+100));
   q=q.gte('study_date',date).lte('study_date',end).order('study_date').order('user_id');return table==='study_activity_completion'?q.order('activity'):q;
  },token));return result;
 }
 async function loadSelection(){
  if(!rosterReady)return;const token=++run,wantedExam=new URLSearchParams(location.search).get('exam');clear();const track=$('course').value,date=$('checkpointDate').value,target=staff?$('student').value:viewer,mode=$('sourceMode').value;
  $('message').textContent='Loading existing objectives…';
  try{
   if(!tracks[track]||!C.validDate(date))throw Error('Choose a valid course and Cairo date.');
   const selected=staff?selectedStudents().filter(s=>!target||s.user_id===target):students;
   if(!selected.length)throw Error('No accessible students are enrolled in this selection.');
   const ids=selected.map(s=>s.user_id),end=target?C.addDays(date,30):date;
   const [all,progress]=await Promise.all([readScope('student_daily_objectives','*',ids,track,date,end,token),readScope('study_activity_completion','user_id,track_id,study_date,activity,status',ids,track,date,end,token)]);
   if(token!==run)return;
   history.replaceState(null,'','/checkpoint.html?'+selectionParams());$('back').href=planLink(date,target);
   context={staff,viewer,user:target,track,date,end,all,progress,selected,mode};
   $('message').textContent=(staff?'Instructor':'Student')+' view · existing portal records · Cairo dates';
   if(!target){renderOverview();return;}
   const plan=all.find(p=>p.user_id===target&&p.study_date===date)||null;
   context.plan=plan;$('checkpoint').hidden=false;renderNext();
   if(mode==='objectives'&&!plan)throw Error('No objective assigned. Unassigned work is not pending. Select Existing assessments above to review saved attempts and assignments without a daily plan.');
   if(mode==='assessments'){
    const groupIds=members.filter(m=>m.user_id===target).map(m=>m.group_id);
    const [attempts,direct,groupAssigned]=await Promise.all([
     pages(()=>sb.from('attempts').select('id,exam_id,user_id,exams!inner(track_id)').eq('user_id',target).eq('exams.track_id',track).order('id'),token),
     pages(()=>sb.from('assignments').select('id,exam_id,user_id,group_id,exams!inner(track_id)').eq('user_id',target).eq('exams.track_id',track).order('id'),token),
     groupIds.length?pages(()=>sb.from('assignments').select('id,exam_id,user_id,group_id,exams!inner(track_id)').in('group_id',groupIds).eq('exams.track_id',track).order('id'),token):[]
    ]);
    if(token!==run)return;
    const links=C.assessmentOptions(plan?[plan]:[],attempts,[...direct,...groupAssigned],[],target,groupIds),metadata=[];
    for(let i=0;i<links.length;i+=100)metadata.push(...await pages(()=>sb.from('exams').select('id,title').eq('track_id',track).in('id',links.slice(i,i+100).map(l=>l.id)).order('id'),token));
    if(token!==run)return;context.links=C.assessmentOptions(plan?[plan]:[],attempts,[...direct,...groupAssigned],metadata,target,groupIds);
   }else context.links=C.linkedAssessments(plan);
   if(!context.links.length){$('selection').innerHTML='<h2>No linked assessment found</h2><p>'+(plan?.practice_source==='daily_quiz'?'<a href="'+esc(activityLink(plan,'practice'))+'">Open the existing Daily Quiz →</a> · Daily Quiz scores stay in the portal.':'No saved attempts or linked exams were found in this selection. Existing portal access rules still apply.')+'</p>';return;}
   $('selection').innerHTML='<div class="eyebrow">'+esc(tracks[track])+' · '+esc(selected[0].full_name)+'</div><label>Existing assessment<select id="assessmentSelect">'+context.links.map(l=>'<option value="'+esc(l.id)+'">'+esc(l.title?l.title+' · '+l.sources.join(' / '):l.activities.map(a=>activities[a]).join(' + '))+'</option>').join('')+'</select></label><small>A shared assessment appears once. Existing assessments include assigned work and recorded attempts, regardless of the selected date. Portal access windows and retake rules still apply.</small>';
   if(context.links.some(l=>l.id===wantedExam))$('assessmentSelect').value=wantedExam;
   $('assessmentSelect').onchange=()=>loadAssessment();await loadAssessment();
  }catch(e){if(token===run){clear();$('message').textContent=e.message;}}
 }
 function progressLabel(plan,activity){const row=context.progress.find(r=>r.user_id===plan.user_id&&r.track_id===plan.track_id&&r.study_date===plan.study_date&&r.activity===activity);return statusLabels[row?.status]||'Progress unavailable';}
 function renderOverview(){
  const {selected,all,date}=context;$('overview').hidden=false;
  if(context.mode==='assessments'){$('overview').innerHTML='<h2>Group assessment review</h2><p>Open a student’s existing assigned assessments and recorded attempts. No daily plan is required. Choose Dated study objectives above for group completion.</p><ul>'+selected.map(s=>'<li><a href="/checkpoint.html?'+esc(selectionParams(s.user_id))+'">'+esc(s.full_name||'Student')+' →</a></li>').join('')+'</ul>';return;}
  $('overview').innerHTML='<h2>Group checkpoints</h2><p>'+selected.length+' selected student'+(selected.length===1?'':'s')+' · '+esc(date)+'. Completion is read from existing objectives; missing plans are not zero scores.</p><div class="checkpoint-table"><table><thead><tr><th>Student</th><th>Objective</th><th>Lesson</th><th>Practice</th><th>Retest</th></tr></thead><tbody>'+selected.map(s=>{const p=all.find(p=>p.user_id===s.user_id&&p.study_date===date);return '<tr><td><a href="/checkpoint.html?'+esc(selectionParams(s.user_id))+'">'+esc(s.full_name||'Student')+' →</a></td><td>'+esc(p?.title||'No objective assigned')+'</td>'+Object.keys(activities).map(a=>'<td>'+esc(p?progressLabel(p,a):'Not assigned')+'</td>').join('')+'</tr>';}).join('')+'</tbody></table></div><p><a href="'+esc(planLink(date,''))+'">Open the existing group Study Plan →</a></p><small>Choose a student to inspect attempts, review availability and supported priorities. No assessment is created for the group.</small>';
 }
 async function loadAssessment(){
  const token=++run;clearAssessment();const current=context,id=$('assessmentSelect').value;current.exam=null;current.attempts=[];
  $('plan').textContent='Loading linked assessment…';
  try{
   const link=current.links.find(l=>l.id===id);if(!link)throw Error('Select an existing assessment from this objective.');
   const exam=(await rows(sb.from('exams').select('id,track_id,title,question_ids,duration_seconds,review_policy,module_count,module_number,is_published').eq('id',id).eq('track_id',current.track)))[0];
   if(!exam||exam.track_id!==current.track)throw Error('The linked assessment is unavailable in this course. Its existing assignment is unchanged.');
   const attempts=await pages(()=>sb.from('attempts').select('id,status,score,total,submitted_at,started_at,time_used,attempt_no').eq('user_id',current.user).eq('exam_id',id).order('started_at',{ascending:false}).order('id',{ascending:false}),token);
   if(token!==run)return;Object.assign(current,{exam,attempts,link});const params=selectionParams();params.set('exam',exam.id);history.replaceState(null,'','/checkpoint.html?'+params);renderPlan();renderAttempts();
   if(staff){$('audit').hidden=false;$('audit').innerHTML='<h2>Question reuse checks</h2><p>Check recorded exam answers, Daily Quizzes and earlier plan links through the selected Cairo date. Counts can overlap.</p><label>History window<select id="auditWindow"><option value="30">Past 30 days</option><option value="90">Past 90 days</option><option value="all">All accessible history</option></select></label><label><input id="auditBank" type="checkbox"> Also compare stems across this course’s accessible question bank</label><button id="auditRun">Check existing question use</button><div id="auditResult" role="status"></div>';$('auditRun').onclick=()=>audit(token);}
   if(attempts.length)await loadAttempt(attempts[0].id,token);
  }catch(e){if(token===run){clearAssessment();$('plan').textContent=e.message;}}
 }
 function renderPlan(){
  const {exam,link}=context,plan=context.plan&&C.linkedAssessments(context.plan).some(l=>l.id===exam.id)?context.plan:null,count=(exam.question_ids||[]).length,minutes=Number.isFinite(exam.duration_seconds)&&exam.duration_seconds>0?Math.ceil(exam.duration_seconds/60):null;
  context.minutes=minutes;
  $('plan').innerHTML='<div class="eyebrow">'+esc(context.date)+' · '+esc(plan?.title||'Existing assessment review')+'</div><h2>'+esc(exam.title)+'</h2><p>'+count+' questions · '+(minutes===null?'Duration unverified':minutes+' minutes')+' · '+(plan?.calculator_allowed?'Calculator allowed in plan':'Check calculator rules')+'</p><small>Calculator guidance comes from the Study Plan. Follow the rules shown inside the linked assessment.</small><p>'+esc(plan?.instructions||'Review existing records. No objective or assignment is created.')+'</p><p>'+(plan&&link.activities.length?link.activities.map(a=>activities[a]+': '+progressLabel(plan,a)).map(esc).join(' · '):'Existing record · daily objective completion is separate')+'</p>'+
   (exam.module_count>1?'<p class="checkpoint-warning">Module '+esc(exam.module_number)+' of '+esc(exam.module_count)+'. The existing next-module and review-release rules still apply. Reserve any additional module time in the workload below.</p>':'')+
   (!exam.is_published?'<p class="checkpoint-warning">This assessment is not published. No student access is assumed.</p>':'')+
   '<div class="checkpoint-actions"><a href="'+esc('/?'+new URLSearchParams({study_track:context.track,study_activity:'full_exam',study_exam:exam.id}))+'">View existing portal assessment →</a><a href="'+esc(historyLink())+'">Existing scores &amp; released solutions →</a></div><small>Opening a link does not start an assessment. The portal keeps its own timer, answer saving, grading, graphs, tables and retake rules.</small>';
  $('budget').innerHTML='<h2>Plan the whole day</h2><p>Reserve '+(minutes??'the verified assessment time')+' minutes for this assessment. Include lessons, other modules, assignments and offline work in the other mathematics total.</p><div class="checkpoint-budget"><label>Corrections, minutes<input id="correctionMinutes" type="number" min="5" max="60" step="1" value="25"></label><label>Daily limit, minutes<input id="dailyLimit" type="number" min="30" max="120" step="1" value="120"></label><label>Other mathematics, minutes<input id="otherMinutes" type="number" min="0" step="1" inputmode="numeric" placeholder="Enter total, including lessons"></label></div><p id="budgetResult" role="status">Enter the other workload to check the plan.</p><small>Planning settings apply to this view only. The daily limit cannot exceed two hours. Offline workload is self-reported; this workspace cannot prevent work opened elsewhere.</small>';
  for(const id of ['otherMinutes','correctionMinutes','dailyLimit'])$(id).oninput=updateBudget;
 }
 function workload(){return C.workload($('otherMinutes').value,context.minutes,Number($('correctionMinutes').value),Number($('dailyLimit').value));}
 function updateBudget(){const b=workload();$('budgetResult').textContent=!b.valid?'Enter valid minutes: corrections 5–60, daily limit 30–120, and other work 0 or more. Assessment duration must be verified.':b.allowed?b.total+' / '+b.limit+' minutes planned · '+b.remaining+' minutes remaining.':b.total+' minutes exceeds the '+b.limit+'-minute daily limit. Move additional work to another day.';if($('clock')&&!$('correctionStart').disabled)$('clock').textContent=Number.isInteger(Number($('correctionMinutes').value))?$('correctionMinutes').value+':00':'—';}
 function renderAttempts(){
  const {attempts}=context;
  $('results').innerHTML='<h2>Checkpoint evidence</h2>'+(!attempts.length?'<p>No attempt recorded. This is pending work, not a score of zero.</p>':'<label>Existing attempt<select id="attemptSelect">'+attempts.map(a=>'<option value="'+esc(a.id)+'">Attempt '+esc(a.attempt_no)+' · '+esc(a.status)+' · '+esc(a.submitted_at?.slice(0,10)||a.started_at?.slice(0,10))+'</option>').join('')+'</select></label><div id="attemptEvidence"></div>');
  $('priorities').innerHTML='<h2>Two priorities for the next lesson</h2><p>Priorities need released, verified item evidence. Missing submissions and unanswered questions are not counted as incorrect answers.</p>';
  $('corrections').innerHTML='<h2>Corrections</h2><p>Complete the linked assessment first. Worked solutions remain subject to the existing portal review policy.</p>';
  if($('attemptSelect'))$('attemptSelect').onchange=()=>loadAttempt($('attemptSelect').value,run);
 }
 async function loadAttempt(id,token){
  const selected=++attemptRequest;clearInterval(clock);const {exam}=context,attempt=context.attempts.find(a=>a.id===id);$('correctionMinutes').disabled=false;
  $('attemptEvidence').textContent='Loading recorded answers…';$('priorities').innerHTML='<h2>Two priorities for the next lesson</h2><p>Waiting for verified evidence.</p>';$('corrections').innerHTML='<h2>Corrections</h2><p>Checking review availability…</p>';
  try{
   const answers=await pages(()=>sb.from('attempt_answers').select('question_id,response').eq('attempt_id',id).order('question_id'),token);
   if(token!==run||selected!==attemptRequest)return;const s=C.summary(attempt,answers,exam.question_ids);
   $('attemptEvidence').innerHTML='<div class="checkpoint-metrics">'+[['Correct',s.correct],['Incorrect',s.incorrect],['Unanswered',s.unanswered],['Answered',s.answered]].map(([label,value])=>'<div><strong>'+esc(value??'—')+'</strong>'+label+'</div>').join('')+'</div><p>'+(!s.complete?'This attempt is still in progress. No diagnostic score is inferred.':!s.reliable?'A complete scored breakdown could not be verified. The portal score remains authoritative.':'Recorded raw score: '+s.correct+'/'+s.total+'. No scaled exam score is estimated.')+'</p><small>Counts describe this selected assessment or module only. Retakes remain separate.</small>';
   if(!s.complete){$('corrections').innerHTML='<h2>Corrections</h2><p>Finish this attempt in the existing portal first.</p>';return;}
   if(staff){
    $('corrections').innerHTML='<h2>Corrections</h2><p>Use the existing instructor results and question-review tools. Student solutions stay locked until the portal releases them. The workload above includes your chosen corrections time.</p><a href="/admin.html?'+esc(new URLSearchParams({track:context.track,section:'results'}))+'">Open instructor results →</a>';
    $('priorities').innerHTML='<h2>Two priorities for the next lesson</h2><p>Load verified history for this student and course. This follows the existing Diagnosis evidence rules and is not a checkpoint-only diagnosis.</p><button id="historyDiagnosis">Load verified skill history</button><div id="historyPriority"></div>';
    $('historyDiagnosis').onclick=()=>loadStaffPriorities(token,selected);return;
   }
   const {data:{session}}=await sb.auth.getSession();if(!session)throw Error('Sign in again to load released review.');
   const response=await fetch(api+'/functions/v1/attempt-review?attempt_id='+encodeURIComponent(id),{headers:{Authorization:'Bearer '+session.access_token,apikey:key}});
   if(!response.ok)throw Error('Review is unavailable. Use the existing portal results.');const payload=await response.json();if(token!==run||selected!==attemptRequest)return;
   const review=C.selectModule(payload,id);
   if(!review?.review_open){$('corrections').innerHTML='<h2>Corrections</h2><p class="checkpoint-warning">Worked solutions are not released for this assessment. Keep corrections pending and ask your instructor to review the plan. No answer keys are unlocked by this workspace.</p>';$('priorities').innerHTML='<h2>Two priorities for the next lesson</h2><p>Checkpoint skill diagnosis is pending released item evidence. No weaknesses are guessed from unanswered questions.</p>';return;}
   renderPriorities(C.priorities(review.items),'This checkpoint: released, eligible questions with recorded responses.');renderCorrections(id,token,selected);
  }catch(e){if(token===run&&selected===attemptRequest){$('attemptEvidence').textContent=e.message;$('corrections').innerHTML='<h2>Corrections</h2><p>Review availability could not be verified. Please refresh.</p>';}}
 }
 function renderPriorities(priorities,note){$('priorities').innerHTML='<h2>Two priorities for the next lesson</h2><p>'+esc(note)+'</p>'+(priorities.length?'<ol>'+priorities.map(p=>'<li><strong>'+esc(p.topic)+'</strong> · '+p.incorrect+' incorrect of '+p.answered+' answered.'+(p.answered<3?' Limited evidence; confirm with a short retest.':'')+'</li>').join('')+'</ol>':'<p>No verified incorrect-answer priorities are available yet.</p>')+(priorities.length===1?'<p>Only one supported priority was found. A second is not invented.</p>':'')+'<p>Review the existing future practice links below for a suitable skill match. New selections need an instructor review and question reuse check.</p>';}
 async function loadStaffPriorities(token,selected){
  const host=$('historyPriority'),{track,user}=context;host.textContent='Loading verified history…';
  try{const {data,error}=await sb.rpc('staff_diagnosis',{p_track:track});if(error||data?.track_id!==track)throw Error('Verified diagnosis is unavailable for this course.');if(token!==run||selected!==attemptRequest)return;
   const student=(data.students||[]).find(s=>s.user_id===user);if(!student)throw Error('No authorized diagnosis evidence for this student.');
   const priorities=(student.lessons||[]).filter(l=>l.classified===true&&Number(l.seen)-Number(l.blank)>=3&&Number(l.missed)-Number(l.blank)>0).map(l=>({topic:l.lesson,answered:Number(l.seen)-Number(l.blank),incorrect:Number(l.missed)-Number(l.blank)})).sort((a,b)=>b.incorrect-a.incorrect||b.incorrect/b.answered-a.incorrect/a.answered).slice(0,2);
   renderPriorities(priorities,'Verified portal history, not only this checkpoint. Locked, excluded and unanswered items are not used as incorrect-answer evidence.');
  }catch(e){if(token===run&&selected===attemptRequest)host.textContent=e.message;}
 }
 function renderCorrections(id,token,selected){
  $('corrections').innerHTML='<h2>Corrections</h2><p>Review incorrect answers first, then unanswered items. Write the first incorrect step, explain the corrected method and redo the problem without looking. Keep the original score unchanged.</p><a href="'+esc(historyLink())+'">Open existing worked solutions and figures →</a><p class="checkpoint-clock" id="clock">'+esc($('correctionMinutes').value)+':00</p><button id="correctionStart">Start correction timer</button><p id="clockNote">Timer only. Completion is not recorded by time spent.</p>';
  const notebook=document.createElement('div');notebook.id='savedCorrections';
  if(['sat','est','est2'].includes(context.track)){
   notebook.innerHTML='<h3>Saved correction practice</h3><p>Use the existing Mistake notebook. Its server-graded practice is saved to your account and is available on your approved devices. Notebook totals cover this course; they do not certify that this particular attempt has been corrected.</p><a href="'+esc('/?'+new URLSearchParams({study_track:context.track,study_activity:'mistakes'}))+'">Open saved Mistake notebook →</a><p><button id="loadNotebook">Refresh saved course progress</button></p><p id="notebookProgress" role="status">Load progress after practising. The optional timer below does not mark work complete.</p>';
   $('corrections').prepend(notebook);$('loadNotebook').onclick=()=>loadNotebook(token,selected);
  }else{notebook.innerHTML='<h3>Saved correction practice</h3><p>Notebook tracking is unavailable for this course in the current portal service. Use released solutions and an existing assigned retest. This workspace will not claim corrections are complete.</p>';$('corrections').prepend(notebook);}
  const storageKey='ghoneem-checkpoint-clock-v2:'+viewer+':'+context.user+':'+context.track+':'+context.date+':'+id;
  let saved=null;try{const r=JSON.parse(localStorage.getItem(storageKey));if(Number.isInteger(r?.minutes)&&r.minutes>=5&&r.minutes<=60&&Number.isFinite(r.end)&&r.end>0&&r.end<=Date.now()+r.minutes*60000)saved=r;}catch{}
  const tick=()=>{const left=Math.max(0,Math.ceil((saved.end-Date.now())/1000));$('clock').textContent=Math.floor(left/60)+':'+String(left%60).padStart(2,'0');if(!left){clearInterval(clock);$('clockNote').textContent='Time is up. Leave unfinished corrections pending for the next session.';}};
  const resume=()=>{$('correctionMinutes').value=saved.minutes;$('correctionMinutes').disabled=true;$('correctionStart').disabled=true;updateBudget();tick();if(saved.end>Date.now())clock=setInterval(tick,1000);};
  $('correctionStart').onclick=()=>{if(!workload().allowed){$('clockNote').textContent='Check the workload above and stay within your daily limit (maximum 120 minutes) before corrections.';return;}saved={minutes:Number($('correctionMinutes').value),end:Date.now()+Number($('correctionMinutes').value)*60000};try{localStorage.setItem(storageKey,JSON.stringify(saved));}catch{$('clockNote').textContent='Storage unavailable: timer will not survive a reload.';}resume();};if(saved)resume();
 }
 async function loadNotebook(token,selected){
  const button=$('loadNotebook'),host=$('notebookProgress'),track=context.track;button.disabled=true;host.textContent='Loading saved course practice…';
  try{
   const {data:{session}}=await sb.auth.getSession();if(!session)throw Error('Sign in again to load saved corrections.');
   if(token!==run||selected!==attemptRequest)return;
   const response=await fetch(api+'/functions/v1/daily-challenge?'+new URLSearchParams({track,view:'notebook',offset:'0'}),{headers:{Authorization:'Bearer '+session.access_token,apikey:key}});
   if(!response.ok)throw Error('Saved notebook progress is unavailable. Open the existing notebook to check.');
   const data=await response.json();if(token!==run||selected!==attemptRequest)return;
   if(data.track!==track||!Number.isInteger(data.remaining)||data.remaining<0||!Number.isInteger(data.mastered)||data.mastered<0)throw Error('Notebook progress could not be verified.');
   host.textContent=data.remaining+' questions to practise · '+data.mastered+' mastered in this course. Saved by the portal; original exam scores are unchanged.';
  }catch(e){if(token===run&&selected===attemptRequest)host.textContent=e.message;}
  finally{if(token===run&&selected===attemptRequest)button.disabled=false;}
 }
 function renderNext(){const {all,user,date,end}=context,future=all.filter(p=>p.user_id===user&&p.study_date>date);
  $('next').innerHTML='<h2>Future targeted practice</h2><p>Existing objectives through '+esc(end)+'. Completion and skipping follow the portal’s current rules.</p>'+(future.length?'<div class="checkpoint-table"><table><thead><tr><th>Cairo date</th><th>Objective &amp; budget</th><th>Lesson</th><th>Practice</th><th>Retest</th></tr></thead><tbody>'+future.map(p=>'<tr><td><a href="'+esc(planLink(p.study_date,user))+'">'+esc(p.study_date)+'</a></td><td>'+esc(p.title)+'<small>'+esc(p.time_budget||'Budget unverified')+'</small></td>'+Object.keys(activities).map(a=>{const label=progressLabel(p,a),url=activityLink(p,a);return '<td>'+esc(label)+(url?'<small><a href="'+esc(url)+'">'+(a==='practice'&&p.practice_source==='daily_quiz'?'Existing Daily Quiz':'Existing assessment')+' →</a></small>':label==='Skipped by instructor'?'<small>No assessment required</small>':'<small>Assessment link needed</small>')+'</td>';}).join('')+'</tr>').join('')+'</tbody></table></div>':'<p>No later objectives are available in this 30-day window. No practice is invented or assigned.</p>');
 }
 async function audit(token){
  const host=$('auditResult');$('auditRun').disabled=true;host.textContent='Checking recorded question use…';
  try{
   const {exam,user,track,date}=context,ids=[...new Set(exam.question_ids||[])],window=$('auditWindow').value;
   const from=window==='all'?null:C.addDays(date,-(Number(window)-1)),until=C.addDays(date,1),questions=[],includeBank=$('auditBank').checked;
   if(!ids.length)throw Error('Question IDs are missing; reuse cannot be verified.');
   for(let i=0;i<ids.length;i+=100)questions.push(...await rows(sb.from('questions').select('id,stem,topic,type,difficulty').in('id',ids.slice(i,i+100))));
   const [earlierPlans,attempts,daily]=await Promise.all([
    pages(()=>{let q=sb.from('student_daily_objectives').select('lesson_exam_id,practice_exam_id,retest_exam_id,practice_source').eq('user_id',user).eq('track_id',track).lt('study_date',date).order('study_date');return from?q.gte('study_date',from):q;},token),
    pages(()=>{let q=sb.from('attempts').select('id,started_at').eq('user_id',user).lt('started_at',until+'T00:00:00Z').order('id');return from?q.gte('started_at',C.addDays(from,-1)+'T00:00:00Z'):q;},token),
    pages(()=>{let q=sb.from('daily_progress').select('day,group_scope,answers,quiz_completed_at').eq('user_id',user).eq('track_id',track).lte('day',date).order('day').order('group_scope');return from?q.gte('day',from):q;},token)
   ]);
   const recent=attempts.filter(a=>{const d=C.cairoDate(a.started_at);return (!from||d>=from)&&d<=date;});if(recent.length>2000)throw Error('Too many historical attempts for a browser audit. Choose a shorter window; verification is incomplete.');const previousIds=[...new Set(earlierPlans.flatMap(p=>C.linkedAssessments(p).map(l=>l.id)))],earlierExams=[],answers=[];
   for(let i=0;i<previousIds.length;i+=100)earlierExams.push(...await rows(sb.from('exams').select('id,question_ids').in('id',previousIds.slice(i,i+100))));
   for(let i=0;i<recent.length;i+=50)for(let j=0;j<ids.length;j+=100)answers.push(...await pages(()=>sb.from('attempt_answers').select('attempt_id,question_id,response').in('attempt_id',recent.slice(i,i+50).map(a=>a.id)).in('question_id',ids.slice(j,j+100)).order('attempt_id').order('question_id'),token));
   const bank=includeBank?await pages(()=>sb.from('questions').select('id,stem').eq('track_id',track).order('id'),token):null;
   if(token!==run)return;
   if(questions.length!==ids.length||earlierExams.length!==previousIds.length)throw Error('Some question or earlier-assessment metadata is unavailable; reuse verification is incomplete.');
   const a=C.audit(exam.question_ids,questions,answers,earlierExams),dailyUse=C.dailyQuestionUse(daily),chosen=new Set(ids),dailyAnswered=dailyUse.answeredIds.filter(id=>chosen.has(id)),dailyExposed=dailyUse.exposedIds.filter(id=>chosen.has(id));
   const union=new Set([...answers.filter(a=>C.answered(a.response)).map(a=>a.question_id),...dailyAnswered]),matches=bank?C.bankMatches(questions,bank):null;
   host.innerHTML='<p>'+esc(from?from+' through '+date:'All accessible history through '+date)+' · selected assessment attempts are included.</p><ul><li>'+a.duplicateIds+' repeated IDs and '+a.duplicateStems+' repeated normalized stems within this assessment.</li><li>'+a.recentlyAnswered+' questions answered in recorded exam attempts.</li><li>'+dailyAnswered.length+' questions answered in completed Daily Quizzes; '+dailyExposed.length+' selected IDs appear in saved Daily Quiz answers.</li><li>'+union.size+' distinct questions answered across exams and Daily Quizzes.</li><li>'+a.earlierPlanOverlap+' questions linked in earlier objectives. Counts may overlap.</li><li>'+(matches===null?'Course-bank stem comparison was not requested.':matches.length+' other question IDs have a matching normalized stem in the accessible course bank. Review choices and figures before deciding they are duplicates.')+'</li></ul><p class="checkpoint-warning">This is recorded-use evidence, not automatic release clearance. Permissions may limit coverage. Offline worksheets, deleted/reset history, conceptual similarity and content outside this course bank remain unverified. No questions or assignments are changed.</p>';
  }catch(e){if(token===run)host.textContent=e.message;}finally{if(token===run)$('auditRun').disabled=false;}
 }
 $('sourceMode').onchange=()=>loadSelection();$('course').onchange=()=>loadRoster();$('checkpointDate').onchange=()=>loadSelection();$('group').onchange=()=>{renderStudents();loadSelection();};$('student').onchange=()=>loadSelection();
 window.addEventListener('pageshow',e=>{if(e.persisted)boot();});
 sb.auth.onAuthStateChange?.((event,session)=>{if(event==='SIGNED_OUT'){run++;rosterReady=false;students=[];groups=[];members=[];clear();$('scope').hidden=true;$('message').textContent='Sign in to view Checkpoints.';}else if(event==='SIGNED_IN'&&viewer&&session?.user?.id&&session.user.id!==viewer){boot();}});
 boot();
})();
