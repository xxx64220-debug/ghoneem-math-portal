// Original source archive: table access is restricted to authorized EST staff by RLS.
const sourceStatus = s => ({ready:'Ready in question bank',duplicate:'Duplicate',excluded:'Excluded',not_a_question:'Answer-key fragment',ocr_screened_not_verified:'Awaiting visual verification',ambiguous_distribution:'Ambiguous question',partial_multi_question:'Multiple questions — needs splitting'}[s] || (s.startsWith('worked')?'Worked — needs final preparation':'Needs source repair'));
async function sourceReview(){
 const {data,error}=await sb.from('est_source_review').select('id,track_id,source_document,source_code,source_page,source_section,review_status,question_id,duplicate_of').order('source_code').limit(1000);
 if(error)throw error;
 const rows=(data||[]).filter(x=>!ST.track||x.track_id===ST.track);
 $('view').innerHTML=`<div class="head"><h2>EST source review</h2><span class="hint">${rows.length} source entries</span></div><p class="hint" style="margin-bottom:16px">Both uploaded PDFs are preserved here. Entries may be duplicates, fragments, or several questions together. Only “Ready in question bank” entries are available for exam composition. Other answers are provisional.</p><div class="actions"><input id="sourceSearch" aria-label="Search source entries" placeholder="Question code, section or PDF"><select id="sourceStatus" aria-label="Review status"><option value="">All review statuses</option>${[...new Set(rows.map(x=>x.review_status))].sort().map(s=>`<option value="${esc(s)}">${esc(sourceStatus(s))} (${rows.filter(x=>x.review_status===s).length})</option>`).join('')}</select></div><p id="sourceCount" class="hint" style="margin:12px 0"></p><div id="sourceTable"></div>`;
 const paint=()=>{
  const needle=$('sourceSearch').value.trim().toLowerCase(),status=$('sourceStatus').value;
  const filtered=rows.filter(x=>(!status||x.review_status===status)&&[x.source_code,x.source_section,x.source_document].join(' ').toLowerCase().includes(needle));
  $('sourceCount').textContent=filtered.length+' matching entries';
  $('sourceTable').innerHTML=wrapTable(`<table><thead><tr><th>Code</th><th>PDF / page</th><th>Review status</th><th></th></tr></thead><tbody>${filtered.map(x=>`<tr><td>${esc(x.source_code)}</td><td>${esc(x.source_document)} · ${x.source_page}</td><td>${esc(sourceStatus(x.review_status))}${x.duplicate_of?` · ${esc(x.duplicate_of)}`:''}</td><td><button class="btn-sm" data-source-id="${esc(x.id)}">View original & analysis</button></td></tr>`).join('')}</tbody></table>`);
  document.querySelectorAll('[data-source-id]').forEach(b=>b.onclick=()=>openSourceEntry(b.dataset.sourceId));
 };
 $('sourceSearch').oninput=paint;$('sourceStatus').onchange=paint;paint();
}
let sourceOpenSerial=0;
async function openSourceEntry(id){
 const serial=++sourceOpenSerial;
 const modal=$('editor');
 modal.innerHTML='<p>Loading original question…</p><button class="btn-sm" id="closeSource">Close</button>';
 $('closeSource').onclick=()=>modal.close();modal.showModal();
 let objectURL;
 modal.addEventListener('close',()=>{if(objectURL)URL.revokeObjectURL(objectURL);},{once:true});
 try{
  const {data:r,error}=await sb.from('est_source_review').select('*').eq('id',id).single();
  if(error)throw error;
  const bytes=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
  const response=await fetch(r.image_path);if(!response.ok)throw new Error('The original image could not be loaded.');
  const key=await crypto.subtle.importKey('raw',bytes(r.image_key_base64),'AES-GCM',false,['decrypt']);
  const plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:bytes(r.image_iv_base64),additionalData:new TextEncoder().encode(r.id)},key,await response.arrayBuffer());
  const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',plain))].map(x=>x.toString(16).padStart(2,'0')).join('');
  if(hash!==r.image_sha256)throw new Error('The source image failed its integrity check.');
  if(!modal.open||serial!==sourceOpenSerial)return;
  objectURL=URL.createObjectURL(new Blob([plain],{type:'image/png'}));
  modal.innerHTML=`<h2>${esc(r.source_code)}</h2><p>${esc(sourceStatus(r.review_status))}</p><p class="hint">${esc(r.source_document)} · page ${r.source_page}</p><img src="${objectURL}" alt="Original ${esc(r.source_code)}" style="max-width:100%;height:auto;margin:16px 0"><p><a href="${objectURL}" download="${esc(r.source_code.replace(' ','-'))}.png">Download original image</a></p><h3 style="margin-top:20px">${r.question_id?'Worked answer':'Provisional analysis'}</h3><p>${r.worked_answer==null?'No verified answer recorded.':esc(typeof r.worked_answer==='string'?r.worked_answer:JSON.stringify(r.worked_answer))}</p><p style="white-space:pre-wrap;line-height:1.6">${esc(r.review_note)}</p>${r.duplicate_of?`<p>Duplicate reference: ${esc(r.duplicate_of)}</p>`:''}<details style="margin:16px 0"><summary>Extracted source text — may contain OCR errors</summary><p style="white-space:pre-wrap">${esc(r.source_text)}</p></details><button class="btn" id="closeSource">Close</button>`;
  $('closeSource').onclick=()=>modal.close();
 }catch(e){if(modal.open&&serial===sourceOpenSerial){modal.innerHTML=`<p role="alert">${esc(e.message||'Could not load this source entry.')}</p><button class="btn" id="closeSource">Close</button>`;$('closeSource').onclick=()=>modal.close();}}
}
