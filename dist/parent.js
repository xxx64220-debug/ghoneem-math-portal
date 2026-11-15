const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function ent(t) {
  const d = document.createElement('textarea');
  d.innerHTML = String(t ?? '');
  return d.value;
}
function drawFig(spec) {
  const H = spec.h || 230, W = 360;
  let o = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="figure">`;
  for (const L of (spec.lines || [])) {
    o += `<line x1="${L[0]}" y1="${L[1]}" x2="${L[2]}" y2="${L[3]}"
            stroke="var(--navy)" stroke-width="1.8" stroke-linecap="round"/>`;
    if (L.length >= 7 && L[4]) {
      o += `<text x="${L[5]}" y="${L[6]}" font-size="13" font-style="italic"
              fill="var(--navy)">${esc(ent(L[4]))}</text>`;
    }
  }
  for (const A of (spec.arcs || [])) {
    const [cx, cy, d1x, d1y, d2x, d2y] = A;
    const t = A.length > 6 ? ent(A[6]) : '';
    const r = A.length > 7 ? A[7] : 26;
    const sx = cx + r * d1x, sy = cy + r * d1y;
    const ex = cx + r * d2x, ey = cy + r * d2y;
    const sweep = (d1x * d2y - d1y * d2x) > 0 ? 1 : 0;
    o += `<path d="M ${sx.toFixed(2)} ${sy.toFixed(2)} A ${r} ${r} 0 0 ${sweep}
            ${ex.toFixed(2)} ${ey.toFixed(2)}" fill="none"
            stroke="var(--gold)" stroke-width="1.6"/>`;
    let bx = d1x + d2x, by = d1y + d2y;
    let m = Math.hypot(bx, by);
    if (m < 1e-6) { bx = -d1y; by = d1x; m = 1; }
    bx /= m; by /= m;
    o += `<text x="${(cx + (r + 15) * bx).toFixed(1)}" y="${(cy + (r + 15) * by).toFixed(1)}"
            font-size="12.5" fill="var(--navy)" text-anchor="middle"
            dominant-baseline="middle">${esc(t)}</text>`;
  }
  if (spec.extra) o += cleanMarkup(ent(spec.extra));
  return o + '</svg>';
}
function cleanMarkup(markup){
 const doc=new DOMParser().parseFromString(markup,'text/html');
 const tags=new Set('svg g path line rect circle ellipse polygon polyline text tspan defs marker table thead tbody tr th td caption colgroup col div span p br b i strong em sup sub u mark figure figcaption img'.split(' '));
 const attrs=new Set('viewBox xmlns d x y x1 y1 x2 y2 cx cy r rx ry width height points fill stroke stroke-width transform text-anchor dominant-baseline font-size font-style colspan rowspan scope role aria-label src alt'.toLowerCase().split(' '));
 for(const el of [...doc.body.querySelectorAll('*')]){
  if(!tags.has(el.localName)){el.remove();continue;}
  if(el.localName==='img'&&!(/^(https:\/\/)/.test(el.getAttribute('src')||'')||/^data:image\/(png|jpeg|jpg|webp|gif);base64,[A-Za-z0-9+/=\s]+$/.test(el.getAttribute('src')||''))){el.remove();continue;}
  if(el.localName!=='img'){el.removeAttribute('src');el.removeAttribute('alt');}
  for(const a of [...el.attributes])if(!attrs.has(a.name.toLowerCase())||/url\s*\(|javascript:/i.test(a.value))el.removeAttribute(a.name);
 }
 return doc.body.innerHTML;
}
function figure(a) {
  if (!a) return '';
  let out = '';
  const figures=Array.isArray(a.figure)?a.figure:[a.figure];
  for(const src of figures){
    if(typeof src!=='string')continue;
    if(/^data:image\/svg\+xml;base64,[A-Za-z0-9+/=\s]+$/.test(src)){
      try{
        const bytes=Uint8Array.from(atob(src.slice(src.indexOf(',')+1)),c=>c.charCodeAt(0));
        const markup=new TextDecoder('utf-8',{fatal:true}).decode(bytes);
        const parsed=new DOMParser().parseFromString(markup,'image/svg+xml');
        if(!parsed.querySelector('parsererror')&&parsed.documentElement.localName==='svg')out+=`<div class="fig">${cleanMarkup(markup)}</div>`;
      }catch{}
    }else if(/^(https:\/\/)/.test(src)||/^data:image\/(png|jpeg|jpg|webp|gif);base64,[A-Za-z0-9+/=\s]+$/.test(src))out+=`<div class="fig"><img src="${esc(src)}" alt="${esc(a.figure_caption||'Question diagram')}" style="max-width:100%;height:auto"></div>`;
  }
  if (a.figspec) out += `<div class="fig">${cleanMarkup(drawFig(a.figspec))}</div>`;
  if (a.html) out += a.passage_title?`<div class="english-passage" lang="en" dir="ltr" aria-label="${esc(a.passage_title)}">${cleanMarkup(ent(a.html))}</div>`:`<div class="fig fig-table">${cleanMarkup(ent(a.html))}</div>`;
  if(a.svg) out+=`<div class="fig">${cleanMarkup(a.svg)}</div>`;
  if(a.image&&/^https:\/\//.test(a.image))out+=`<div class="fig"><img src="${esc(a.image)}" alt="${esc(a.image_alt || 'Question diagram')}" style="max-width:100%;height:auto"></div>`;
  if((a.source_question||a.source_code) && a.image && /^https:\/\//.test(a.image))out+=`<p style="margin:8px 0 18px;font-size:14px"><a href="${esc(a.image)}" target="_blank" rel="noopener">${a.source_question?'Enlarge original question':'Enlarge diagram'}</a></p>`;
  if(a.source_code)out+=`<p class="dash-note">Source: ${esc(a.source_document||'Question bank')} · ${esc(a.source_code)}</p>`;
  if(a.source_question) {
    const links=[['instructions','Paper instructions'],['reference','Formula reference']].filter(([key])=>typeof a[key]==='string'&&/^https:\/\//.test(a[key])).map(([key,label])=>`<a href="${esc(a[key])}" target="_blank" rel="noopener">${label}</a>`);
    out+=`<p style="font-size:14px;margin:10px 0 18px">${links.join(' · ')}</p>`;
  }
  return out;
}
const fmt = v => v?.void ? 'Excluded from scoring' : Array.isArray(v) ? v.join('  or  ') : (v == null ? '' : String(v));
const token=location.hash.slice(1);
const byId=id=>document.getElementById(id);

async function request(action,extra={}){
 const send=async(proof={})=>
 fetch('https://wfhurjyouemahvkcfkdz.supabase.co/functions/v1/parent-progress',{method:'POST',cache:'no-store',credentials:'omit',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,token,...extra,...proof})});
 let response=await send();
 if(response.status===409 && action==='summary'){
  try{
   const identity=await openFamilyIdentity();
   response=await send(await identity.proof(action,token,extra));
  }catch{throw Error('Ask your instructor to replace this older link.');}
 }
 if(!response.ok)throw Error(response.status===403?'This private link is unavailable. Ask your instructor for a current link.':'Could not load progress. Please try again.');
 return response.json();
}
const cairoClock=new Intl.DateTimeFormat(undefined,{timeZone:'Africa/Cairo',day:'numeric',month:'short',year:'numeric',hour:'numeric',minute:'2-digit'});
function attemptTiming(attempt){
 const stamp=value=>value && Number.isFinite(Date.parse(value))?esc(cairoClock.format(new Date(value))):'Not recorded';
 const seconds=attempt.time_used;
 let elapsed='Not recorded';
 if(Number.isInteger(seconds)&&seconds>=0){
  const hours=Math.floor(seconds/3600),minutes=Math.floor(seconds/60)%60;
  elapsed=(hours?hours+'h ':'')+(hours||minutes?minutes+'m ':'')+seconds%60+'s';
 }
 return '<small>Started (Cairo): '+stamp(attempt.started_at)+'<br>Submitted (Cairo): '+stamp(attempt.submitted_at)+'<br>Elapsed time: <strong>'+elapsed+'</strong></small>';
}
function scoreOverview(groups){
 const states=['Completed','Still due','Missed','Upcoming'];
 const completed=groups.Completed?.count||0;
 const assigned=states.reduce((sum,key)=>sum+(groups[key]?.count||0),0);
 const marks=groups.recent_marks||[];
 const rows=marks.map(m=>{
  return '<li><strong>'+esc(m.score)+' / '+esc(m.total)+' ('+Math.round(100*m.score/m.total)+'%)</strong> · '+esc(m.title)+'<br><small>'+esc(m.track_id.toUpperCase())+' · Attempt '+esc(m.attempt_no)+'</small><br>'+attemptTiming(m)+'</li>';
 }).join('');
 return '<section id="familyScores"><h2>Progress and scores</h2><p><strong>'+completed+' of '+assigned+'</strong> current assignments completed.</p>'+(assigned?'<progress aria-label="Assignment completion" value="'+completed+'" max="'+assigned+'"></progress>':'')+'<h3>Recent scores</h3>'+(rows?'<p>Latest graded attempts first, including retakes.</p><ol>'+rows+'</ol>':'<p>No graded scores yet. Marks appear here after grading.</p>')+'</section>';
}
function renderPractice(skills){
 const section=document.createElement('section');section.id='familyPractice';
 section.innerHTML='<h2>What to practise next</h2><p>Based on the two latest attempts for each topic within the last 20 released, graded attempts. Retakes count.</p>';
 const topics=skills.map(skill=>{
  const rows=skill.attempts;
  const seen=rows.reduce((n,a)=>n+a.seen,0), correct=rows.reduce((n,a)=>n+a.correct,0);
  const repeated=rows.length===2 && seen>=4 && rows.every(a=>a.correct/a.seen<0.7);
  return {...skill,seen,correct,repeated,rate:correct/seen};
 }).filter(s=>s.seen>0).sort((a,b)=>Number(b.repeated)-Number(a.repeated)||a.rate-b.rate||b.seen-a.seen);
 const priorities=topics.filter(s=>s.rate<0.7 || s.attempts.at(-1).correct/s.attempts.at(-1).seen<0.7).slice(0,3);
 if(!priorities.length)section.insertAdjacentHTML('beforeend',topics.length?'<p>No topic fell below 70% in the latest attempt or across the attempts compared.</p>':'<p>There are no released topic scores to build a practice plan yet.</p>');
 for(const skill of priorities){
  const latestMiss=skill.attempts.slice().reverse().find(a=>a.correct<a.seen);
  const card=document.createElement('article');
  card.innerHTML='<h3>'+esc(skill.topic)+' · '+esc(skill.track_id.toUpperCase())+'</h3><p><strong>'+(skill.repeated?'Repeated difficulty':'Check this topic next')+'</strong> · '+skill.correct+'/'+skill.seen+' correct ('+Math.round(skill.rate*100)+'%).</p><p>'+skill.attempts.map(a=>esc(a.title)+' · '+esc(a.correct)+'/'+esc(a.seen)).join(' → ')+'</p><p>Retry one missed '+esc(skill.topic)+' question before opening its solution. Explain the step that went wrong, then try three more questions on this topic.</p>';
  if(latestMiss?.attempt_id){const button=document.createElement('button');button.textContent='Review '+latestMiss.title;button.onclick=()=>openResult({title:latestMiss.title,attempt_id:latestMiss.attempt_id},button);card.append(button);}
  section.append(card);
 }
 const strengths=topics.filter(s=>s.attempts.length===2 && s.seen>=4 && s.attempts.every(a=>a.correct/a.seen>=0.8)).sort((a,b)=>b.rate-a.rate).slice(0,3);
 if(strengths.length)section.insertAdjacentHTML('beforeend','<h3>Strong topics</h3><p>At least 80% on both attempts, with four or more questions in total.</p><ul>'+strengths.map(s=>'<li>'+esc(s.topic)+' · '+esc(s.track_id.toUpperCase())+' · '+s.correct+'/'+s.seen+' correct</li>').join('')+'</ul>');
 if(topics.length)section.insertAdjacentHTML('beforeend','<details><summary>All topic results ('+topics.length+')</summary>'+topics.map(s=>'<p><strong>'+esc(s.topic)+' · '+esc(s.track_id.toUpperCase())+'</strong><br>'+s.attempts.map(a=>esc(new Date(a.date).toLocaleDateString())+' · '+a.correct+'/'+a.seen).join(' → ')+'</p>').join('')+'</details>');
 byId('content').append(section);
}
async function load(){
 if(!token){byId('status').textContent='Open the private link supplied by your instructor to see your child’s work.';return;}

 byId('status').textContent='Loading assignments…';
 try{
 const data=await request('summary');
 byId('status').textContent='';
 byId('student').textContent=data.name;
 byId('familyNavigation').hidden=false;
 byId('content').innerHTML=scoreOverview(data.groups)+'<section><h2>This week’s next step</h2><p>'+esc(data.next_step||'Choose one missed question and retry it together.')+'</p></section>';
 renderPractice(data.skills||[]);
 for(const state of ['Still due','Missed','Completed','Upcoming']){
 const {rows=[],count=0}=data.groups[state]||{};
 const group=document.createElement('details');group.id={ 'Still due':'familyDue',Missed:'familyMissed',Completed:'familyCompleted',Upcoming:'familyUpcoming'}[state];group.open=state==='Still due';
 const summary=document.createElement('summary');summary.textContent=state+' ('+count+')';group.append(summary);
 let offset=0;
 function more(batch=rows){
 offset+=batch.length;
 for(const row of batch){
 const article=document.createElement('article');
 article.innerHTML='<h3>'+esc(row.title)+'</h3><small>'+esc(row.track.toUpperCase())+' · '+(row.due_at?'Due '+esc(new Date(row.due_at).toLocaleString(undefined,{timeZone:'Africa/Cairo'}))+' Cairo time':'No deadline')+'</small>';
 if(row.attempt_id){const p=document.createElement('p');p.textContent=row.score==null?'Awaiting grading':row.score+' / '+row.total;p.append(' ');const b=document.createElement('button');b.textContent='View review';b.onclick=()=>openResult(row,b);p.append(b);article.append(p);}group.append(article);
 }
 if(batch.length&&offset<count){const b=document.createElement('button');b.textContent='Show more';b.onclick=async()=>{b.disabled=true;try{const next=await request('page',{state,offset});b.remove();more(next.rows);}catch(e){byId('status').textContent=e.message;b.disabled=false;}};group.append(b);}
 }
 if(rows.length){if(group.open)more();else group.addEventListener('toggle',()=>{if(group.open&&offset===0)more();});}else group.append('No assignments in this category.');
 byId('content').append(group);
 }
 }catch(e){byId('status').textContent=e.message;}
}
let reviewRequest=0;
async function openResult(row,button){
 const generation=++reviewRequest,panel=byId('review');button.disabled=true;panel.hidden=false;panel.textContent='Loading review…';panel.focus();
 try{
 const data=await request('review',{attempt:row.attempt_id});if(generation!==reviewRequest)return;
 panel.innerHTML='<h2>'+esc(row.title)+'</h2>'+(data.timing?attemptTiming(data.timing):'');
 for(const [index,module] of data.modules.entries()){
 if(data.modules.length>1)panel.insertAdjacentHTML('beforeend','<h3>Module '+(index+1)+'</h3>');
 if(!module.open){panel.insertAdjacentHTML('beforeend','<p>Worked answers have not been released.</p>');continue;}
 module.items.forEach((item,i)=>panel.insertAdjacentHTML('beforeend','<article><strong>Question '+(i+1)+'</strong><p class="stem">'+esc(item.stem)+'</p>'+figure(item.assets)+(item.choices||[]).map(c=>'<div>'+esc(c.key)+'. '+esc(c.text)+'</div>').join('')+'<p><b>Submitted answer</b> '+esc(fmt(item.response)||'Blank')+'<br><b>Correct answer</b> '+esc(fmt(item.correct))+'</p><p class="worked">'+esc(item.explanation||'No worked solution recorded.')+'</p></article>'));
 }
 const back=document.createElement('button');back.textContent='← Back to progress';back.onclick=()=>{panel.hidden=true;button.focus();};panel.prepend(back);
 window.PortalMath?.render(panel);
 }catch(e){if(generation===reviewRequest)panel.textContent=e.message;}finally{button.disabled=false;}
}
load();

document.getElementById('familyNavigation')?.addEventListener('click',event=>{const a=event.target.closest('[data-family-target]');if(!a)return;const section=document.getElementById(a.dataset.familyTarget);if(!section)return;if(section.tagName==='DETAILS')section.open=true;section.tabIndex=-1;section.focus({preventScroll:true});section.scrollIntoView?.({block:'start',behavior:'auto'});});
