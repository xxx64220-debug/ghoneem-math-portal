// Runs only in the isolated audit document or the browser test fixture.
// Uses the real page's renderQ/paintReview and normal navigation/save handlers.
window.mathLayoutChecks = (() => {
 const pause=()=>new Promise(resolve=>setTimeout(resolve,20));
 const visible=el=>el.getBoundingClientRect().width>0&&el.getBoundingClientRect().height>0;
 function inspect(root,q,surface){
  const issues=[],width=document.documentElement.clientWidth;
  if(document.documentElement.scrollWidth>width+1)issues.push('Page overflow: '+document.documentElement.scrollWidth+' > '+width);
  if(root.querySelector('.katex-error'))issues.push('KaTeX parse error');
  if(root.querySelector('.katex')&&!document.fonts.check('20px KaTeX_Main'))issues.push('KaTeX font not loaded');
  if(root.querySelector('.delimsizing')&&!document.fonts.check('20px KaTeX_Size3'))issues.push('KaTeX delimiter font not loaded');
  const stem=root.querySelector('.stem');
  if(!stem||!visible(stem))issues.push('Missing stem');
  if(q.id==='currency'&&stem?.textContent!==q.stem)issues.push('Currency/prose changed');
  if(q.id==='mixed'&&!stem?.textContent.includes('The final sentence must remain visible.'))issues.push('Text after percentage lost');
  if(stem?.querySelectorAll('.katex').length!==q.mathCount)issues.push('Unexpected stem math count');
  const choices=root.querySelectorAll(surface==='exam'?'.choice-text':'.review-choice>span');
  if(q.type==='mcq'&&choices.length!==q.choices.length)issues.push('Missing choices');
  for(const choice of choices){
   const r=choice.getBoundingClientRect();
   if(!visible(choice)||r.left<0||r.right>width+1)issues.push('Choice outside viewport');
   if(choice.scrollWidth>choice.clientWidth+1&&getComputedStyle(choice).overflowX!=='auto')issues.push('Choice content overflows');
   if(choice.scrollHeight>choice.clientHeight+1)issues.push('Choice mathematics needs vertical scrolling');
  }
  // Every oversized mathematical box must have a reachable local scroller.
  for(const box of root.querySelectorAll('.katex-html>.base')){
   if(!visible(box))continue;
   const r=box.getBoundingClientRect();let scroll=box.parentElement;
   while(scroll&&scroll!==root&&getComputedStyle(scroll).overflowX!=='auto')scroll=scroll.parentElement;
   if(r.left<-1||r.right>width+1){if(!scroll||scroll===root)issues.push('Uncontained mathematical expression');}
   if(scroll&&scroll!==root){
    const s=scroll.getBoundingClientRect();
    if(r.top<s.top-1||r.bottom>s.bottom+1)issues.push('Mathematics clipped vertically');
    const glyphs=[...box.querySelectorAll('.mord,.delimsizing,.sqrt-sign')].filter(el=>!el.children.length);
    if(glyphs.some(el=>{const g=el.getBoundingClientRect();return g.top<s.top-1||g.bottom>s.bottom+1;}))issues.push('Mathematical glyph clipped vertically');
    if(scroll.scrollWidth>scroll.clientWidth+1){
     scroll.scrollLeft=scroll.scrollWidth;
     if(box.getBoundingClientRect().right>scroll.getBoundingClientRect().right+1)issues.push('Final math term unreachable');
     scroll.scrollLeft=0;
    }
   }
  }
  const table=root.querySelector('.fig-table');
  if(table){
   const cell=table.querySelector('tr:last-child td:last-child');table.scrollLeft=table.scrollWidth;
   if(cell.getBoundingClientRect().right>table.getBoundingClientRect().right+1)issues.push('Final table cell unreachable');
   table.scrollLeft=0;if(!root.textContent.includes('$1,250.50'))issues.push('Table currency lost');
  }
  for(const svg of root.querySelectorAll('.fig svg')){
   const r=svg.getBoundingClientRect();if(!visible(svg)||r.right>width+1)issues.push('Diagram outside viewport');
  }
  return {viewport:window.innerWidth,width,track:ST.run.exam.track_id,question:q.id,surface,issues};
 }
 async function start(){
  for(let i=0;i<180&&!document.querySelector('[data-start="math-audit"]');i++){
   const full=document.querySelector('[data-view="full_exam"]');if(full)full.click();await pause();
  }
  document.querySelector('[data-start="math-audit"]').click();
  for(let i=0;i<180&&document.getElementById('vRun').classList.contains('hidden');i++)await pause();
  await document.fonts.ready;await pause();
 }
 async function preview(index,surface='exam'){
  if(surface==='exam'){
   show('vRun');document.querySelectorAll('#palette [data-i]')[index].click();
  }else{
   const q=window.mathAuditCases[index];
   paintReview({exam:ST.run.exam,attempt:{score:0,total:1},review_open:true,items:[{...q,correct:'B',response:'B',is_correct:true,explanation:q.stem}]});show('vReview');
  }
  await document.fonts.ready;await pause();
  window.mathAuditFontStatus={katex:[...document.fonts].some(f=>f.family==='KaTeX_Main'&&f.status==='loaded'),inter:[...document.fonts].some(f=>f.family==='Inter'&&f.status==='loaded')};
 }
 async function run(){
  const results=[],clockStart=document.getElementById('clock').textContent;
  for(let index=0;index<window.mathAuditCases.length;index++){
   const q=window.mathAuditCases[index];
   for(const surface of ['exam','review']){
    await preview(index,surface);
    results.push(inspect(document.getElementById(surface==='exam'?'qcard':'vReview'),q,surface));
   }
  }
  await preview(0);document.querySelector('.choice[data-k="B"]').click();document.getElementById('flagBtn').click();
  await preview(1);await preview(0);
  const issues=[];
  if(!document.querySelector('.choice[data-k="B"].sel'))issues.push('Selected response lost on navigation');
  if(document.getElementById('flagBtn').getAttribute('aria-pressed')!=='true')issues.push('Flag lost on navigation');
  for(let i=0;i<180&&document.getElementById('clock').textContent===clockStart;i++)await pause();
  const seconds=text=>text.split(':').reduce((n,v)=>n*60+Number(v),0);
  if(!(seconds(document.getElementById('clock').textContent)<seconds(clockStart)))issues.push('Timer stopped or reset');
  await preview(7);const input=document.getElementById('gin');input.value='3/4';input.dispatchEvent(new Event('input',{bubbles:true}));
  await preview(0);await preview(7);if(document.getElementById('gin').value!=='3/4')issues.push('Grid response lost');
  for(let i=0;i<180&&(!window.__savedAnswers.some(a=>a.response==='B')||!window.__savedAnswers.some(a=>a.response==='3/4'));i++)await pause();
  if(!window.__savedAnswers.some(a=>a.response==='B')||!window.__savedAnswers.some(a=>a.response==='3/4'))issues.push('Fixture saves not recorded');
  if(window.__unexpectedRequests.length)issues.push('Unexpected backend request');
  results.push({viewport:window.innerWidth,width:document.documentElement.clientWidth,track:ST.run.exam.track_id,question:'saved-state',surface:'navigation',issues});
  await preview(0);return results;
 }
 return {start,preview,run};
})();
window.mathLayoutChecks.start().then(()=>{window.mathAuditReady=true;});
