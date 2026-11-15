/* Shared presentation only. Course access and assessment rules stay in their existing owners. */
(function(root){
 'use strict';
 const title=value=>String(value||'').replace(/\s*[—–-]\s*[0-9a-f]{6,}$/i,'').trim();
 const scoreBand=value=>value==null||!Number.isFinite(Number(value))?'none':Number(value)>=70?'ok':Number(value)>=40?'warn':'bad';
 const day=value=>{const d=new Date(value);return Number.isNaN(d.getTime())?'Date unavailable':new Intl.DateTimeFormat('en-GB',{weekday:'short',day:'numeric',month:'short',timeZone:'Africa/Cairo'}).format(d);};
 const api={title,scoreBand,day};root.PortalUI=api;
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(typeof document==='undefined')return;
 function setupHeader(){
  const header=document.querySelector('body > header');if(!header)return;
  header.classList.add('portal-header');
  const host=header.querySelector(':scope > .wrap')||header;
  let brand=host.querySelector('.brand')||host.querySelector('a:first-child:has(span)');
  if(!brand){brand=document.createElement('a');brand.href='/';brand.className='brand';host.prepend(brand);}
  brand.classList.add('portal-brand');brand.innerHTML='Abdelrahman Ghoneem<span>MATH PORTAL</span>';
  let menu=document.getElementById('portalAccountMenu');
  if(!menu){
   menu=document.createElement('details');menu.id='portalAccountMenu';menu.className='portal-account';
   const summary=document.createElement('summary');summary.textContent='☰';summary.setAttribute('aria-label','Account and portal menu');
   const items=document.createElement('nav');items.className='portal-account-items';items.setAttribute('aria-label','Account');menu.append(summary,items);host.append(menu);
   document.addEventListener('click',event=>{if(!menu.contains(event.target))menu.open=false;});
   menu.addEventListener('keydown',event=>{if(event.key==='Escape'){menu.open=false;summary.focus();}});
   items.addEventListener('click',event=>{if(event.target.closest('a,button'))menu.open=false;});
  }
  const items=menu.querySelector('nav');
  function collect(){
   for(const element of [...host.children]){
    if(element===brand||element===menu||element.matches('.spacer,.sp'))continue;
    if(element.tagName==='SELECT'){
     const label=document.createElement('label');label.textContent='Course';label.append(element);items.append(label);continue;
    }
    if(element.id==='portalBack'||(element.tagName==='A'&&/←|Back|My courses/i.test(element.textContent))){
     element.classList.add('portal-breadcrumb');header.after(element);continue;
    }
    if(element.matches('button,a,.track-chip,.headerlinks'))items.append(element);
   }
   if(!document.getElementById('top')&&!items.querySelector('[data-account-home]')){
    const home=document.createElement('a');home.href='/';home.dataset.accountHome='true';home.textContent='My courses & account';items.prepend(home);
   }
  }
  collect();new MutationObserver(collect).observe(host,{childList:true});
 }
 function cleanTitles(){
  document.querySelectorAll('h1,h2,h3,.score .lbl,.search-history strong,.student-table td b').forEach(el=>{
   if(el.childElementCount)return;const clean=title(el.textContent);if(clean!==el.textContent)el.textContent=clean;
  });
 }
 function ready(){
  document.body.classList.add('portal-shared-ui');
  setupHeader();cleanTitles();
  let queued=false;new MutationObserver(()=>{if(queued)return;queued=true;queueMicrotask(()=>{queued=false;cleanTitles();});}).observe(document.body,{childList:true,subtree:true});
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ready);else ready();
})(typeof globalThis!=='undefined'?globalThis:this);
