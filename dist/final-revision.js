// Final revision: answers are checked and saved by the server.
const REV_COLLECTIONS={
 priority:['Priority revision','Must-know skills, repeated ideas and unique approaches together. One question per idea in each set.'],
 must_know:['Must know','Core skills with several question variations. Start here to check your foundations.'],
 repeated:['Most repeated ideas','Ideas represented by at least four different reviewed questions. These counts describe this revision bank, not official exam frequencies.'],
 unique:['Unique approaches','Selected questions with distinctive methods, shortcuts and nonroutine twists.'],
 all:['Full revision bank','Every available question in the revision bank.']
};
let REV={track:null,data:null,session:null,index:0,loading:false,busy:false,error:'',scope:'both',source:'both',lesson:'',level:'mixed',collection:'priority',draft:''};
function revisionText(text,source,format){
 const value=esc(String(text??'').replace(/\\{2}(?=[a-zA-Z])/g,'\\'));
 const currency='<span class="revision-currency">$</span>';
 return source==='est'&&format!=='latex'?value.replaceAll('$',currency):value.replace(/\$(?=\d[\d,]*(?:\.\d+)?(?:\s+(?:for|per|each|to|and|is|a|in|on|was|by|of|among|before|while|dollars|from)\b|[.,]\s|$))/g,()=>currency);
}
function revisionFigure(assets){
 // HTML tables in the May paper contain prices, not math delimiters.
 // Wrap their currency signs after the existing markup sanitizer runs.
 return figure(assets).replace(/(<div class="fig fig-table">)([\s\S]*?)(<\/div>)/g,(_,open,body,close)=>open+body.replace(/\$(?=\d)/g,'<span class="revision-currency">$</span>')+close);
}
function resetRevision(track){REV={track,data:null,session:null,index:0,loading:false,busy:false,error:'',scope:track,source:track==='est'?'est':'both',lesson:'',level:'mixed',collection:'priority',draft:''};}
function revisionPaint(){if(DASH.view==='revision'&&!DASH.searchTerm?.trim())paintDashboardContent();}
async function revisionRequest(action,extra={}){
 const track=ST.track?.id,current=REV;
 const {ok,json}=await fn('final-revision',{method:'POST',body:{track,action,...extra}});
 if(!ok)throw new Error(friendly(json.error));
 if(ST.track?.id!==track||REV!==current)return null;
 return json;
}
async function refreshRevision(){
 const track=ST.track?.id;if(!['sat','est'].includes(track))return;
 if(REV.track!==track)resetRevision(track);
 if(REV.loading)return;REV.loading=true;REV.error='';revisionPaint();
 try{const data=await revisionRequest('catalogue');if(!data)return;REV.data=data;REV.session=data.session;REV.index=Math.max(0,data.session?.questions.findIndex(q=>!q.feedback)??0);}
 catch(e){if(REV.track===track)REV.error=e.message;}
 finally{if(REV.track===track){REV.loading=false;revisionPaint();}}
}
function revisionInCollection(q,collection=REV.collection){const tags=q.focus?.collections||[];return collection==='all'||(collection==='priority'?tags.length>0:tags.includes(collection));}
function revisionRows(){return(REV.data?.items||[]).filter(q=>(ST.track?.id!=='est'||q.source==='est')&&revisionInCollection(q)&&(ST.track?.id==='est'||REV.scope==='both'||q.programmes.includes(REV.scope))&&(ST.track?.id==='est'||REV.source==='both'||q.source===REV.source)&&(REV.level==='mixed'||q.difficulty===REV.level));}
function revisionCollections(){return `<nav class="revision-collections" aria-label="Revision collections">${Object.entries(REV_COLLECTIONS).map(([id,[name]])=>`<button class="btn-ghost ${REV.collection===id?'selected':''}" data-revision-collection="${id}" aria-pressed="${REV.collection===id}">${name}</button>`).join('')}</nav><p class="dash-notice">${esc(REV_COLLECTIONS[REV.collection]?.[1]||'')}</p>`;}
function revisionPanel(){
 if(REV.loading||(!REV.data&&!REV.error))return '<section class="dash-panel"><h2>Final revision</h2><p role="status">Loading revision questions…</p></section>';
 if(!REV.data)return `<section class="dash-panel"><h2>Final revision</h2><p role="alert">${esc(REV.error)}</p><button class="btn" data-revision-refresh>Try again</button></section>`;
 if(REV.session)return revisionSessionPanel();
 const rows=revisionRows(),lessons=[...new Set(rows.map(q=>q.lesson))].sort();
 const selected=rows.filter(q=>!REV.lesson||q.lesson===REV.lesson),ideaCount=new Set(selected.map(q=>q.lesson+'|'+q.idea)).size;
 const levels=['easy','medium','hard'].map(l=>`${selected.filter(q=>q.difficulty===l).length} ${l}`).join(' · ');
 return `<section class="dash-panel revision-panel"><div class="dash-heading"><h2>Final revision</h2><span class="revision-badge">${ST.track?.id==='est'?'EST I':'SAT + EST I'}</span></div><p class="dash-note">Choose a lesson or mix your practice. Answers and worked solutions appear after you check each question. Checked answers are saved automatically.</p>${revisionCollections()}
 ${REV.data.session?'<p class="dash-notice">You have an unfinished set. <button class="dash-link" data-revision-resume>Resume saved practice</button></p>':''}<div class="revision-filters ${ST.track?.id==='est'?'est-only':''}">${ST.track?.id==='est'?'':`<label>Skills<select data-revision-filter="scope"><option value="both" ${REV.scope==='both'?'selected':''}>All revision skills</option><option value="sat" ${REV.scope==='sat'?'selected':''}>SAT skills</option><option value="est" ${REV.scope==='est'?'selected':''}>EST I skills</option></select></label><label>Question source<select data-revision-filter="source">${[['both','SAT + EST I'],['sat','SAT bank'],['est','EST I bank']].map(([v,l])=>`<option value="${v}" ${REV.source===v?'selected':''}>${l}</option>`).join('')}</select></label>`}<label>Difficulty<select data-revision-filter="level">${[['mixed','Mixed difficulty'],['easy','Easy'],['medium','Medium'],['hard','Hard']].map(([v,l])=>`<option value="${v}" ${REV.level===v?'selected':''}>${l}</option>`).join('')}</select></label><label>Lesson<select data-revision-filter="lesson"><option value="">All lessons</option>${lessons.map(l=>`<option ${REV.lesson===l?'selected':''} value="${esc(l)}">${esc(l)}</option>`).join('')}</select></label></div>
 <div class="revision-start"><div><strong>${selected.length} questions · ${ideaCount} ideas available</strong><p class="dash-note">${levels}</p></div><button class="btn" data-revision-start="10" ${!selected.length||REV.busy?'disabled':''}>Practise up to 10</button><button class="btn-ghost" data-revision-start="20" ${!selected.length||REV.busy?'disabled':''}>Practise up to 20</button></div><p class="dash-note">Untimed · Repeatable${REV.collection!=='all'?' · One question per idea in each set':''} · Mixed sets aim for 30% easy, 40% medium and 30% hard, adjusted to the questions available. Difficulty is an editorial practice guide.</p>${REV.error?`<p role="alert">${esc(REV.error)}</p>`:''}
 <div class="revision-lessons">${lessons.filter(l=>!REV.lesson||l===REV.lesson).map(l=>{const qs=rows.filter(q=>q.lesson===l),ideas=[...new Set(qs.map(q=>q.idea))].sort(),done=qs.filter(q=>q.practised).length;return `<article class="revision-lesson"><h3>${esc(l)}</h3><p class="dash-note">${qs.length} questions · ${done} practised</p><details><summary>${ideas.length} ideas to revise</summary><ul>${ideas.map(i=>`<li>${esc(i)}${REV.collection==='repeated'?` <span class="dash-note">(${qs.find(q=>q.idea===i)?.focus?.bank_occurrences||0} in reviewed bank)</span>`:''}</li>`).join('')}</ul></details><button class="btn-ghost" data-revision-lesson="${esc(l)}" ${REV.busy?'disabled':''}>Practise this lesson</button></article>`;}).join('')}</div></section>`;
}
function revisionSessionPanel(){
 const s=REV.session,qs=s.questions,complete=qs.every(q=>q.feedback),q=qs[REV.index]||qs[0],feedback=q.feedback;
 const correct=qs.filter(q=>q.feedback?.correct).length;
 const selected=feedback?q.response:REV.draft;
 return `<section class="dash-panel revision-panel"><div class="dash-heading"><h2>${esc(s.lesson||REV_COLLECTIONS[s.collection]?.[0]||'Mixed revision')}</h2><button class="dash-link" data-revision-back ${REV.busy?'disabled':''}>${complete?'Choose another set':'Return to lessons'}</button></div><p class="dash-note">Question ${REV.index+1} of ${qs.length} · ${qs.filter(q=>q.feedback).length} checked · ${correct} correct</p>${complete?`<p class="dash-notice">Set complete: ${correct}/${qs.length} correct. Review any question below.${correct<qs.length?' <button class="dash-link" data-revision-retry>Retry mistakes</button>':''}</p>`:''}
 <div class="revision-question-nav" aria-label="Revision questions">${qs.map((x,i)=>`<button class="btn-ghost ${i===REV.index?'current':''}" data-revision-index="${i}" aria-label="Question ${i+1}${x.feedback?(x.feedback.correct?', correct':', needs practice'):''}" aria-current="${i===REV.index?'step':'false'}">${i+1}${x.feedback?(x.feedback.correct?' ✓':' ×'):''}</button>`).join('')}</div>
 <article class="revision-question"><p class="revision-meta">${esc(q.lesson)} · ${esc(q.idea)} <span class="revision-badge">${esc(q.difficulty)}</span> <span>${q.source==='sat'?'SAT':'EST I'}</span></p><div class="stem">${revisionText(q.stem,q.source,q.focus?.math_format)}</div>${revisionFigure(q.assets)}<fieldset class="daily-options"><legend class="sr-only">Your answer</legend>${q.type==='mcq'?q.choices.map(c=>`<label class="daily-option"><input type="radio" name="revision-answer" value="${esc(c.key)}" ${selected===c.key?'checked':''} ${feedback||REV.busy?'disabled':''}><span><b>${esc(c.key)}.</b> ${revisionText(c.text,q.source,q.focus?.math_format)}</span></label>`).join(''):`<label class="field">Your answer<input id="revisionAnswer" class="gridin" maxlength="250" value="${esc(selected||'')}" ${feedback||REV.busy?'disabled':''}></label>`}</fieldset>
 ${feedback?`<div class="daily-solution ${feedback.correct?'right':'wrong'}" role="status"><strong>${feedback.correct?'Correct':'Review this idea'}</strong><p>Accepted answer: ${esc(Array.isArray(feedback.answer)?feedback.answer.join(' or '):feedback.answer)}</p><p>${revisionText(feedback.explanation,q.source,q.focus?.math_format)}</p>${feedback.takeaway?`<p><strong>Key idea:</strong> ${revisionText(feedback.takeaway,q.source)}</p>`:''}</div>`:`<button class="btn" data-revision-check ${REV.busy?'disabled':''}>${REV.busy?'Checking…':'Check answer'}</button>`}
 ${REV.error?`<p role="alert">${esc(REV.error)}</p>`:''}<div class="revision-start"><button class="btn-ghost" data-revision-prev ${REV.index===0||REV.busy?'disabled':''}>Previous</button><button class="btn" data-revision-next ${REV.index===qs.length-1||REV.busy?'disabled':''}>Next question</button></div></article></section>`;
}
async function revisionStart(count,lesson=REV.lesson,retry=null){
 if(REV.busy)return;const current=REV;REV.busy=true;REV.error='';revisionPaint();
 try{const data=await revisionRequest('start',{count,lesson,scope:ST.track?.id==='est'?'est':REV.scope,source:ST.track?.id==='est'?'est':REV.source,difficulty:REV.level,collection:REV.collection,retry});if(!data)return;REV.session=data;REV.index=0;REV.draft='';}
 catch(e){if(REV===current)REV.error=e.message;}
 finally{if(REV===current){REV.busy=false;revisionPaint();}}
}
function wireRevision(){
 document.querySelectorAll('[data-revision-collection]').forEach(b=>b.onclick=()=>{if(REV.busy)return;REV.collection=b.dataset.revisionCollection;REV.lesson='';REV.level='mixed';REV.error='';revisionPaint();});
 document.querySelector('[data-revision-resume]')?.addEventListener('click',()=>{REV.session=REV.data.session;REV.index=Math.max(0,REV.session.questions.findIndex(q=>!q.feedback));REV.draft='';REV.error='';revisionPaint();});
 document.querySelector('[data-revision-refresh]')?.addEventListener('click',refreshRevision);
 document.querySelectorAll('[data-revision-filter]').forEach(el=>el.onchange=()=>{REV[el.dataset.revisionFilter]=el.value;if(el.dataset.revisionFilter!=='lesson')REV.lesson='';REV.error='';revisionPaint();});
 document.querySelectorAll('[data-revision-start]').forEach(b=>b.onclick=()=>revisionStart(Number(b.dataset.revisionStart)));
 document.querySelectorAll('[data-revision-lesson]').forEach(b=>b.onclick=()=>revisionStart(10,b.dataset.revisionLesson));
 document.querySelectorAll('input[name="revision-answer"]').forEach(el=>el.onchange=()=>{REV.draft=el.value;});
 const input=document.getElementById('revisionAnswer');if(input)input.oninput=()=>{REV.draft=input.value.trim();};
 function go(i){if(REV.busy)return;REV.index=i;REV.draft='';REV.error='';revisionPaint();document.querySelector('.revision-question')?.scrollIntoView({block:'start',behavior:'smooth'});}
 document.querySelectorAll('[data-revision-index]').forEach(b=>b.onclick=()=>go(Number(b.dataset.revisionIndex)));
 document.querySelector('[data-revision-prev]')?.addEventListener('click',()=>go(REV.index-1));
 document.querySelector('[data-revision-next]')?.addEventListener('click',()=>go(REV.index+1));
 document.querySelector('[data-revision-back]')?.addEventListener('click',async()=>{REV.session=null;REV.error='';const data=await revisionRequest('catalogue').catch(()=>null);if(data)REV.data=data;revisionPaint();});
 document.querySelector('[data-revision-retry]')?.addEventListener('click',()=>revisionStart(20,'',REV.session.id));
 document.querySelector('[data-revision-check]')?.addEventListener('click',async()=>{
  if(REV.busy)return;if(!REV.draft){REV.error='Choose or enter an answer first.';revisionPaint();return;}
  const current=REV;REV.busy=true;REV.error='';revisionPaint();
  try{const data=await revisionRequest('answer',{session:REV.session.id,question:REV.session.questions[REV.index].id,answer:REV.draft});if(data){REV.session=data;REV.draft='';}}
  catch(e){if(REV===current)REV.error=e.message;}finally{if(REV===current){REV.busy=false;revisionPaint();}}
 });
}
