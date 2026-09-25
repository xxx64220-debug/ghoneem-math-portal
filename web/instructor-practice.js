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
 const tags=new Set('svg g path line rect circle ellipse polygon polyline text tspan defs marker table thead tbody tr th td caption colgroup col div span p br b i strong em sup sub'.split(' '));
 const attrs=new Set('viewBox xmlns d x y x1 y1 x2 y2 cx cy r rx ry width height points fill stroke stroke-width transform text-anchor dominant-baseline font-size font-style colspan rowspan scope role aria-label'.toLowerCase().split(' '));
 for(const el of [...doc.body.querySelectorAll('*')]){
  if(!tags.has(el.localName)){el.remove();continue;}
  for(const a of [...el.attributes])if(!attrs.has(a.name.toLowerCase())||/url\s*\(|javascript:/i.test(a.value))el.removeAttribute(a.name);
 }
 return doc.body.innerHTML;
}
function figure(a) {
  if (!a) return '';
  let out = '';
  const figures=Array.isArray(a.figure)?a.figure:[a.figure];
  for(const src of figures){if(typeof src==='string'&&(/^(https:\/\/)/.test(src)||/^data:image\/(png|jpeg|jpg|webp|gif);base64,[A-Za-z0-9+/=\s]+$/.test(src)))out+=`<div class="fig"><img src="${esc(src)}" alt="${esc(a.figure_caption||'Question diagram')}" style="max-width:100%;height:auto"></div>`;}
  if (a.figspec) out += `<div class="fig">${cleanMarkup(drawFig(a.figspec))}</div>`;
  if (a.html)    out += `<div class="fig fig-table">${cleanMarkup(ent(a.html))}</div>`;
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


async function openTeachingExam(exam){
 if(!exam?.question_ids?.length){alert('This exam has no questions yet.');return;}
 try{
 const [{data:questions,error:qe},{data:keys,error:ke}]=await Promise.all([
 sb.from('questions').select('*').in('id',exam.question_ids),
 sb.from('question_keys').select('question_id,correct,explanation').in('question_id',exam.question_ids)]);
 if(qe||ke)throw qe||ke;
 const rows=exam.question_ids.map(id=>(questions||[]).find(q=>q.id===id));
 if(rows.some(q=>!q))throw new Error('Some questions are unavailable for your account.');
 let index=0;const responses=new Map();let revealed=false;
 const paint=()=>{const q=rows[index],key=(keys||[]).find(k=>k.question_id===q.id),response=responses.get(q.id)||'';
 $('editor').classList.add('teaching');
 $('editor').innerHTML=`<h2>${esc(exam.title)}</h2><p class="hint">Instructor practice · No time limit · Question ${index+1} of ${rows.length}</p><p class="hint">Practice selections stay in this session and do not affect student results.</p><div class="teaching-question">${esc(q.stem)}</div>${figure(q.assets)}<div class="teaching-options">${q.type==='mcq'?(q.choices||[]).map(c=>`<button type="button" data-choice="${esc(c.key)}" class="${response===c.key?'selected':''}" aria-pressed="${response===c.key}"><b>${esc(c.key)}.</b> ${esc(c.text)}</button>`).join(''):`<label>Your answer<input id="teachingInput" value="${esc(response)}" autocomplete="off"></label>`}</div>${revealed?`<div class="teaching-answer"><b>Correct answer:</b> ${key?.correct==null?'Awaiting verified answer key':esc(fmt(key.correct))}${key?.explanation?`<div>${esc(key.explanation)}</div>`:''}</div>`:''}<div class="actions"><button class="btn-sm" id="teachPrev" ${index===0?'disabled':''}>Previous</button><button class="btn" id="teachReveal">${revealed?'Hide answer':'Show answer'}</button><button class="btn-sm" id="teachNext" ${index===rows.length-1?'disabled':''}>Next</button></div><div class="actions"><button class="btn-sm" id="teachRestart">Start again</button><button class="btn-sm" id="teachClose">Close practice</button></div>`;
 if(window.renderMathInElement)window.renderMathInElement($('editor'),{delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false},{left:'\\(',right:'\\)',display:false},{left:'\\[',right:'\\]',display:true}],throwOnError:false});
 $('editor').querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>{responses.set(q.id,b.dataset.choice);paint();});
 if($('teachingInput'))$('teachingInput').oninput=e=>responses.set(q.id,e.target.value);
 $('teachPrev').onclick=()=>{index--;revealed=false;paint();$('editor').scrollTop=0;};
 $('teachNext').onclick=()=>{index++;revealed=false;paint();$('editor').scrollTop=0;};
 $('teachReveal').onclick=()=>{revealed=!revealed;paint();};
 $('teachRestart').onclick=()=>{if(confirm('Clear practice selections and start again?')){responses.clear();index=0;revealed=false;paint();}};
 $('teachClose').onclick=()=>$('editor').close();
 };paint();$('editor').onclose=()=>$('editor').classList.remove('teaching');$('editor').showModal();
 }catch(e){alert('Could not open instructor practice: '+e.message);}
}
