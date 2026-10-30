// Staff-only source catalog. Originals remain at their existing source locations.
let act2DocumentSerial=0;
async function act2Collection(){
 const track=ST.track;if(track!=='act2')return;
 const view=$('view');let request=0,timer;
 view.innerHTML=`<div class="head"><h2>ACT 2 source PDFs</h2><div class="sp"></div><button class="btn-sm" id="collectionBack">Question bank</button></div><p class="hint">59 distinct PDFs · 2,089 pages. Open the original PDFs with their graphs, tables and notation. Source access permissions still apply. Source questions and printed answers require review before scored practice. Text search may miss scanned pages.</p><div class="actions" style="margin:16px 0;flex-wrap:wrap"><input id="collectionSearch" type="search" maxlength="200" aria-label="Search PDFs and extracted page text" placeholder="Search filename, topic or page text"><select id="collectionSubject" aria-label="Source subject"><option value="">All subjects</option><option>Math 1</option><option>Math 2</option><option>Mixed / reference</option></select></div><p id="collectionCount" class="hint" aria-live="polite"></p><div id="collectionResults"></div>`;
 const results=$('collectionResults'),current=()=>ST.track===track&&results.isConnected;
 $('collectionBack').onclick=()=>pagedQuestionBank();
 const load=async()=>{
  const serial=++request;results.innerHTML='';$('collectionCount').textContent='Searching source PDFs…';
  try{
   const {data,error}=await sb.rpc('act2_collection_search',{p_search:$('collectionSearch').value.trim(),p_category:'',p_subject:$('collectionSubject').value});
   if(!current()||serial!==request)return;if(error)throw error;
   $('collectionCount').textContent=`${data.length} PDFs found`;
   results.innerHTML=wrapTable(`<table><thead><tr><th>PDF</th><th>Subject / category</th><th>Pages and notes</th><th>Open original</th></tr></thead><tbody>${data.map(d=>`<tr><td data-label="PDF" style="overflow-wrap:anywhere">${esc(d.filename)}</td><td data-label="Subject / category">${esc(d.subject)}<p class="hint">${esc(d.category)}</p></td><td data-label="Pages and notes">${d.page_count} pages · ${(d.size_bytes/1048576).toFixed(1)} MB<p class="hint">${esc(d.notes)}</p>${d.matching_pages.length?`<p class="hint">Matching pages: ${d.matching_pages.slice(0,12).join(', ')}${d.matching_pages.length>12?'…':''}</p>`:''}</td><td data-label="Open original"><button class="btn-sm" data-act2-doc="${esc(d.id)}" data-page="${d.matching_pages[0]||1}">Open PDF</button></td></tr>`).join('')}</tbody></table>`);
   results.querySelectorAll('[data-act2-doc]').forEach(b=>b.onclick=()=>openAct2Document(b.dataset.act2Doc,Number(b.dataset.page)));
  }catch(e){if(current()&&serial===request){$('collectionCount').textContent='';results.innerHTML=`<p class="msg bad" role="alert">${esc(e.message||'Could not load PDFs.')}</p><button class="btn-sm" id="collectionRetry">Retry</button>`;$('collectionRetry').onclick=load;}}
 };
 $('collectionSearch').oninput=()=>{clearTimeout(timer);request++;results.innerHTML='';timer=setTimeout(load,300);};
 $('collectionSubject').onchange=()=>{clearTimeout(timer);load();};await load();
}
async function openAct2Document(id,page=1){
 const modal=$('editor'),serial=++act2DocumentSerial;
 const current=()=>modal.open&&serial===act2DocumentSerial;
 if(modal.open)modal.close();
 modal.innerHTML='<h2>Opening original PDF</h2><p role="status">Loading source link…</p><button class="btn-sm" id="closeAct2Pdf">Close</button>';
 $('closeAct2Pdf').onclick=()=>modal.close();modal.showModal();
 try{
  const {data:d,error}=await sb.from('act2_collection_documents').select('id,filename,page_count,source_url').eq('id',id).single();if(error)throw error;if(!current())return;
  const url=new URL(d.source_url);
  if(url.protocol!=='https:'||!['www.act.org','global.act.org','www.oxfordschools.edu.jo','drive.google.com','chatgpt.com'].includes(url.hostname))throw Error('The source link is unavailable.');
  page=Math.min(d.page_count,Math.max(1,Math.floor(page)||1));
  if(url.pathname.toLowerCase().endsWith('.pdf'))url.hash='page='+page;
  modal.innerHTML=`<h2 style="overflow-wrap:anywhere">${esc(d.filename)}</h2><p>${d.page_count} pages · Original graphs and tables</p><p class="hint">Opens at its existing source. Google Drive or ChatGPT files may require your source account. Matching page: ${page}.</p><div class="actions" style="margin:12px 0;flex-wrap:wrap"><a class="btn-sm" href="${esc(url.href)}" target="_blank" rel="noopener noreferrer">Open original PDF</a><button class="btn-sm" id="closeAct2Pdf">Close</button></div>`;
  $('closeAct2Pdf').onclick=()=>modal.close();
 }catch(e){if(current()){modal.innerHTML=`<p class="msg bad" role="alert">${esc(e.message||'Could not open the source link.')}</p><button class="btn-sm" id="retryAct2Pdf">Retry</button> <button class="btn-sm" id="closeAct2Pdf">Close</button>`;$('retryAct2Pdf').onclick=()=>openAct2Document(id,page);$('closeAct2Pdf').onclick=()=>modal.close();}}
}
