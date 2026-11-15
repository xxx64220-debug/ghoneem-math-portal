/* Navigation and drafts for the existing planner. No assessment writes or completion controls. */
(() => {
 'use strict';
 const activities=['lesson','practice','retest'];
 const dayFields=['title','instructions','time_budget','lesson','practice_note','retest_note','destination','lesson_exam_id','practice_exam_id','retest_exam_id','practice_source','practice_group_id','calculator_allowed','skip_lesson','skip_practice','skip_retest'];
 let activeDraft=null, baseline=null, roadmapBaseline=null, publishing=false;
 const key=()=> 'ghoneem.planner.drafts.v1.'+me.id;
 const idsEqual=(a,b)=>JSON.stringify([...a].sort())===JSON.stringify([...b].sort());
 const capture=(form,fields)=>Object.fromEntries(fields.map(k=>[k,form.elements[k].type==='checkbox'?form.elements[k].checked:form.elements[k].value]));
 const snapshot=items=>JSON.stringify(items.map(p=>Object.fromEntries(Object.keys(p).sort().map(k=>[k,p[k]]))).sort((a,b)=>String(a.user_id).localeCompare(String(b.user_id))));
 function daySnapshot(target){return snapshot(plans.filter(p=>p.track_id===target.track&&p.study_date===target.date&&target.users.includes(p.user_id)));}
 function drafts(){
  if(!staff||!me)return [];
  const parsed=JSON.parse(localStorage.getItem(key())||'[]');
  if(!Array.isArray(parsed))throw Error('Draft storage could not be read. Existing drafts were kept.');
  return parsed.filter(d=>d&&['day','roadmap'].includes(d.kind)&&typeof d.id==='string'&&d.target&&d.values);
 }
 function storeDrafts(list){localStorage.setItem(key(),JSON.stringify(list));}
 function refreshDraftNotice(){
  $('draftsButton').hidden=!staff;$('draftNotice').hidden=!staff;
  if(!staff)return;
  try{const n=drafts().length;$('draftsButton').textContent='Drafts'+(n?' · '+n:'');$('draftNotice').textContent='Instructor workspace · Save uncertain changes as drafts, then review before publishing. Drafts stay on this browser.';}
  catch{$('draftNotice').textContent='Draft storage is unavailable in this browser. Published plans remain available.';}
 }
 function saveDraft(kind){
  if(!staff||!me||publishing)return;
  const day=kind==='day',target=day?editorTarget:roadmapTarget,error=day?'saveError':'roadmapError';
  if(!target)return;
  try{
   const list=drafts(),scope=day?{track:target.track,date:target.date,users:[...target.users],group:$('group').value}: {...target};
   const same=d=>d.kind===kind&&(day?d.target.track===scope.track&&d.target.date===scope.date&&idsEqual(d.target.users,scope.users):d.target.id===scope.id);
   const existing=list.find(same),id=existing?.id||crypto.randomUUID();
   const entry={id,kind,target:scope,values:capture($(day?'planForm':'roadmapForm'),day?dayFields:['teaching_plan','target_exam_date']),baseline:day?baseline:roadmapBaseline,savedAt:new Date().toISOString()};
   if(!existing&&list.length>=100)throw Error('You have 100 drafts. Remove an old draft before saving another.');
   storeDrafts([...list.filter(d=>d.id!==id),entry]);activeDraft=id;refreshDraftNotice();
   $(error).textContent='Draft saved on this browser. Nothing has been published.';
  }catch(e){$(error).textContent='Draft not saved: '+e.message;}
 }
 function renderDraftList(){
  try{
   $('draftList').innerHTML=drafts().sort((a,b)=>b.savedAt.localeCompare(a.savedAt)).map(d=>'<article class="draft-entry"><span class="flag">DRAFT · '+esc(mathTracks[d.target.track||d.target.track_id]||'Course')+'</span><h3>'+esc(d.kind==='day'?(d.values.title||'Untitled daily plan'):d.target.name+' roadmap')+'</h3><p class="muted">'+esc(d.kind==='day'?d.target.date+' · '+d.target.users.length+' selected students':'Group roadmap')+' · Saved '+esc(windowLabel(d.savedAt))+' Cairo</p><details><summary>Review draft text</summary><p class="draft-text">'+esc(d.kind==='day'?[d.values.lesson,d.values.instructions,d.values.practice_note,d.values.retest_note].filter(Boolean).join('\n\n'):d.values.teaching_plan)+'</p></details><div class="actions"><button type="button" class="secondary" data-remove-draft="'+esc(d.id)+'">Remove draft</button><button type="button" data-open-draft="'+esc(d.id)+'">Resume draft</button></div></article>').join('')||'<div class="empty"><h3>No drafts yet</h3><p>Use Create / edit day or Edit group roadmap, then Save draft.</p></div>';
  }catch(e){$('draftError').textContent=e.message;}
 }
 function applyValues(form,values){
  for(const [name,value] of Object.entries(values)){
   const field=form.elements[name];if(!field)continue;
   if(field.type==='checkbox')field.checked=!!value;
   else{if(field.tagName==='SELECT'&&value&&![...field.options].some(o=>o.value===value))field.add(new Option('Saved link — needs verification',value));field.value=value;}
  }
 }
 async function resumeDraft(id){
  if(!staff||publishing)return;
  try{
   const d=drafts().find(d=>d.id===id);if(!d)return;
   const track=d.target.track||d.target.track_id;
   if(![...$('track').options].some(o=>o.value===track))throw Error('This course is no longer available.');
   $('track').value=track;$('group').value='';$('student').value='';
   if(d.kind==='day'){$('date').value=d.target.date;followToday=d.target.date===today();}
   if(!await load())throw Error('Current plan could not be loaded. The draft is preserved.');
   if(d.kind==='day'){
    if(d.target.group&&!groups.some(g=>g.id===d.target.group))throw Error('The saved group is no longer available.');
    $('group').value=d.target.group||'';selectStudents();
    if(d.target.users.length===1){
     if(![...$('student').options].some(o=>o.value===d.target.users[0]))throw Error('The saved student is no longer in this selection.');
     $('student').value=d.target.users[0];
    }
    if(!idsEqual(selectedUsers().map(s=>s.user_id),d.target.users))throw Error('The group roster changed. Review the saved draft text and create a new draft for the current roster.');
    if(daySnapshot(d.target)!==d.baseline)throw Error('Published objectives changed since this draft was saved. Review the current plan and saved draft text before creating a new draft.');
    render();$('draftLibrary').close();await edit();
    if(!editorTarget)throw Error('The editor could not open. Your draft is preserved.');
    applyValues($('planForm'),d.values);syncPracticeFields();renderPublishReview();
   }else{
    const current=groups.find(g=>g.id===d.target.id);
    if(!current||current.plan_version!==d.target.plan_version)throw Error('This group roadmap changed since the draft was saved. Review the current roadmap and saved draft text.');
    $('draftLibrary').close();await editRoadmap(d.target.id);applyValues($('roadmapForm'),d.values);
   }
   activeDraft=d.id;
  }catch(e){$('draftError').textContent=e.message;message(e.message,true);}
 }
 function publishFlags(){
  if(!editorTarget)return [];
  const f=$('planForm').elements,flags=[];
  if(!scheduleVerified||!assessmentMetadataVerified||!enrollmentVerified)flags.push('Some assessment, assignment or enrolment details are unverified. Save a draft until checked.');
  const linked=[];
  for(const a of activities){
   if(f['skip_'+a].checked)continue;
   if(a==='practice'&&f.practice_source.value==='daily_quiz'){
    if(!f.practice_group_id.value)flags.push('Daily Quiz has no selected group. Confirm which existing quiz applies.');
    continue;
   }
   const id=f[a+'_exam_id'].value;
   if(!id){flags.push(a+': missing assessment link; completion cannot be verified.');continue;}
   if(!exams.some(e=>e.id===id))flags.push(a+': the saved assessment is unavailable or unverified.');
   if(linked.includes(id))flags.push('One assessment is linked to more than one activity. A submission may complete both; this is not a fresh retest.');
   linked.push(id);
   if(scheduleVerified&&editorTarget.users.some(user=>!scheduleAssignments.some(s=>s.exam_id===id&&appliesTo(s,user)&&(!s.open_at||cairoDate(s.open_at)<=editorTarget.date)&&(!s.close_at||cairoDate(s.close_at)>=editorTarget.date))))flags.push(a+': assignment access for this study date is not confirmed for every selected student.');
  }
  for(const issue of planIssues([]))if(issue.kind==='conflict')flags.push(issue.text);
  return [...new Set(flags)];
 }
 function renderPublishReview(){
  if(!editorTarget||!staff)return;
  const flags=publishFlags();$('reviewFlagsLabel').hidden=!flags.length;
  $('publishReview').innerHTML='<div class="publish-review"><strong>'+ (flags.length?'Review before publishing':'Ready for instructor review')+'</strong><p>This publishes objectives for '+editorTarget.users.length+' selected student'+(editorTarget.users.length===1?'':'s')+' on '+esc(editorTarget.date)+'. It links existing work; it creates no assessments.</p>'+(flags.length?'<ul>'+flags.map(f=>'<li>'+esc(f)+'</li>').join('')+'</ul><p>Save a draft while anything is uncertain.</p>':'<p>Current links and assignment windows are available. Review the lesson instructions and calculator setting.</p>')+'</div>';
 }
 async function verifyUnchanged(target){
  const latest=[];
  for(let i=0;i<target.users.length;i+=100)latest.push(...await pages(()=>sb.from('student_daily_objectives').select('*').eq('track_id',target.track).eq('study_date',target.date).in('user_id',target.users.slice(i,i+100)).order('user_id')));
  if(snapshot(latest)!==baseline)throw Error('Published objectives changed while this editor was open. Save a draft, close and reload before publishing.');
 }
 function activeAssignments(date){return selectedAssignments().filter(a=>(!a.open_at||cairoDate(a.open_at)<=date)&&(!a.close_at||cairoDate(a.close_at)>=date));}
 function renderAssignments(){
  const root=$('todayAssignments');root.hidden=calendar||roadmap||progressView;
  if(root.hidden){root.replaceChildren();return;}
  const date=$('date').value,byExam=new Map();
  for(const a of activeAssignments(date)){
   if(!byExam.has(a.exam_id))byExam.set(a.exam_id,[]);byExam.get(a.exam_id).push(a);
  }
  const linked=new Set(relevant().filter(p=>p.study_date===date).flatMap(p=>activities.map(a=>p[a+'_exam_id'])).filter(Boolean));
  const allItems=[...byExam.values()];
  const focused=allItems.filter(list=>linked.has(list[0].exam_id)||list.some(a=>(a.open_at&&cairoDate(a.open_at)===date)||(a.close_at&&cairoDate(a.close_at)===date)));
  const items=focused.sort((a,b)=>Number(b.some(s=>s.group_id===alexSchedule.group&&/Tuesday Algebra/.test(s.exams?.title||'')))-Number(a.some(s=>s.group_id===alexSchedule.group&&/Tuesday Algebra/.test(s.exams?.title||''))));
  const featured=items.slice(0,6);
  const shortcut=(label,student,section)=>'<a href="'+esc(staff?'/admin.html?'+new URLSearchParams({track:$('track').value,section}):'/?'+new URLSearchParams({study_track:$('track').value,study_activity:student,study_date:date}))+'">'+label+' →</a>';
  root.innerHTML='<section class="today-work"><div class="today-work-heading"><div><div class="eyebrow">EXISTING PORTAL WORK</div><h2>Assigned for this day</h2></div><nav class="today-shortcuts" aria-label="Daily work">'+shortcut('Assignments','assignments','exams')+shortcut(staff?'Lesson exams':'Lessons','practice','exams')+shortcut('Retests','retakes','results')+'</nav></div><p class="muted">Assessment availability is shown here. Completion comes from submitted work; an open window does not mean an assessment is unfinished.</p>'+(featured.length?featured.map(list=>{
   const a=list[0],exam=a.exams||{},weekly=list.some(s=>s.group_id===alexSchedule.group&&/Tuesday Algebra/.test(s.exams?.title||''));
   const time=exam.duration_seconds?Math.round(exam.duration_seconds/60)+' min':'Follow assessment timer';
   const links=new URLSearchParams({study_track:$('track').value,study_exam:a.exam_id,study_date:date});
   const target=staff?'/admin.html?'+new URLSearchParams({section:'exams',track:$('track').value}):'/?'+links;
   return '<article class="today-assignment '+(weekly?'weekly-assignment':'')+'"><div>'+(weekly?'<span class="flag">ALEX TUESDAY ALGEBRA · EXISTING ASSESSMENT</span>':'')+'<h3>'+esc(exam.title||'Assigned assessment')+'</h3><small>'+esc(time)+' · Follow assessment calculator rules</small>'+list.map(s=>'<p class="assignment-window">'+esc(s.group_id?(groups.find(g=>g.id===s.group_id)?.name||'Assigned group'):(staff?(students.find(u=>u.user_id===s.user_id)?.full_name||'Individual assignment'):'Personal assignment'))+' · Opens '+esc(windowLabel(s.open_at))+' · New-start cutoff '+esc(windowLabel(s.close_at))+' Cairo</p>').join('')+'</div><a class="assessment-link" href="'+esc(target)+'">'+(staff?'Review in Exams':'Open assessment')+' →</a></article>';
  }).join(''):'<p class="muted">'+(scheduleVerified?'No linked daily task or assessment opening/closing is recorded for this day. Your other assignments remain available below.':'Assignment availability is unverified. Open the portal to check your existing work.')+'</p>')+'<div class="assignment-browse">'+(items.length>6?'<span>'+items.length+' relevant assessments · Showing the first 6.</span>':'')+shortcut(scheduleVerified?'Browse all '+allItems.length+' assignments':'Browse existing assignments','assignments','exams')+'</div>'+(expectedAlex(date)&&!exactAlex(date)?'<p class="weekly-unverified"><strong>Alex Tuesday algebra · Unverified</strong><br>The recurring assessment is expected. Its dated link is not visible yet; check the existing quiz before class.</p>':'')+'</section>';
 }
 function renderStatus(){
  const root=$('statusOverview');root.hidden=roadmap||progressView;
  if(root.hidden){root.replaceChildren();return;}
  const counts={completed:0,pending:0,skipped:0,needs_link:0,unavailable:0};
  for(const p of relevant().filter(p=>p.study_date===$('date').value))for(const a of activities){const s=state(p,a);counts[s==='in_progress'?'pending':Object.hasOwn(counts,s)?s:'unavailable']++;}
  const labels={completed:'Completed',pending:'Pending / started',skipped:'Skipped',needs_link:'Missing links',unavailable:'Unverified'};
  root.innerHTML='<div class="status-overview" aria-label="Daily objective statuses">'+Object.entries(counts).map(([s,n])=>'<div class="status-total '+s+'"><span>'+labels[s]+'</span><strong>'+n+'</strong></div>').join('')+'</div><p class="status-note">Skipped and unassigned work are not counted as completed. Missing submissions are not recorded as wrong answers.</p>';
 }
 const previousRender=render;render=function(){const result=previousRender.apply(this,arguments);if(!loading){refreshDraftNotice();renderStatus();renderAssignments();}return result;};
 const previousEdit=edit;edit=async function(){activeDraft=null;baseline=null;await previousEdit.apply(this,arguments);if(editorTarget){baseline=daySnapshot(editorTarget);$('planForm').elements.review_flags.checked=false;renderPublishReview();}};$('edit').onclick=edit;
 const previousRoadmap=editRoadmap;editRoadmap=async function(){activeDraft=null;await previousRoadmap.apply(this,arguments);roadmapBaseline=roadmapTarget?JSON.stringify(roadmapTarget):null;};
 const originalSubmit=$('planForm').onsubmit;
 $('planForm').onsubmit=async e=>{
  e.preventDefault();if(publishing)return;
  if(!staff||!editorTarget){$('saveError').textContent='Not saved: Reopen the instructor editor.';return;}
  if(editorTarget.replacing&&!e.target.elements.replace_existing.checked){await originalSubmit(e);return;}
  if(publishFlags().length&&!e.target.elements.review_flags.checked){$('saveError').textContent='Not published: review the flags or save a draft.';return;}
  publishing=true;const controls=[...e.target.elements].map(el=>[el,el.disabled]);controls.forEach(([el])=>el.disabled=true);
  const draftId=activeDraft;
  try{
   await verifyUnchanged(editorTarget);
   await originalSubmit(e);
   if(!editorTarget&&draftId){storeDrafts(drafts().filter(d=>d.id!==draftId));activeDraft=null;refreshDraftNotice();}
  }catch(error){$('saveError').textContent='Not published: '+error.message;}
  finally{publishing=false;controls.forEach(([el,disabled])=>el.disabled=disabled);}
 };
 const originalRoadmapSubmit=$('roadmapForm').onsubmit;
 $('roadmapForm').onsubmit=async e=>{e.preventDefault();if(publishing)return;publishing=true;$('saveRoadmapDraft').disabled=true;const id=activeDraft;try{await originalRoadmapSubmit(e);if(!roadmapTarget&&id){storeDrafts(drafts().filter(d=>d.id!==id));activeDraft=null;refreshDraftNotice();}}finally{publishing=false;$('saveRoadmapDraft').disabled=false;}};
 $('planForm').addEventListener('input',e=>{if(e.target.name!=='review_flags'){$('planForm').elements.review_flags.checked=false;renderPublishReview();}});
 $('saveDraft').onclick=()=>saveDraft('day');$('saveRoadmapDraft').onclick=()=>saveDraft('roadmap');
 $('draftsButton').onclick=()=>{if(!staff)return;$('draftError').textContent='';renderDraftList();$('draftLibrary').showModal();};
 $('closeDrafts').onclick=()=>$('draftLibrary').close();
 $('draftList').onclick=e=>{const open=e.target.closest('[data-open-draft]'),remove=e.target.closest('[data-remove-draft]');if(open)void resumeDraft(open.dataset.openDraft);if(remove&&staff){try{storeDrafts(drafts().filter(d=>d.id!==remove.dataset.removeDraft));renderDraftList();refreshDraftNotice();}catch(error){$('draftError').textContent=error.message;}}};
 globalThis.PlannerWorkspace={saveDraft,resumeDraft,publishFlags,activeAssignments,snapshot};
})();
