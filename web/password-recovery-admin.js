(function(){
 'use strict';let status='pending',offset=0,serial=0,lastLink=null,badgeAt=0,badgeBusy=false,routeChecked=false;
 const errors={identity_required:'Confirm the student’s identity before approving.',account_unavailable:'No matching active student account. Check the username with the student; this request cannot be approved.',request_expired:'This request is over seven days old. Ask the student for a new request.',already_reviewed:'This request was already decided. Refresh the list.',link_busy:'A reset link is being prepared. Wait one minute before trying again.',link_failed:'Approval is saved, but a reset link could not be confirmed. Retry, or find this request under Approved.',forbidden:'Only administrators can review password requests.',signed_out:'Sign in again to review this request.',session_unavailable:'Your administrator session could not be verified. Reopen the console and try again.'};
 async function api(body){const controller=new AbortController();let timer;const deadline=new Promise((_,reject)=>{timer=setTimeout(()=>{controller.abort();const e=Error('timeout');e.name='AbortError';reject(e);},15000);});try{const r=await Promise.race([fn('password-recovery',{body,signal:controller.signal}),deadline]);if(!r.ok)throw Error(errors[r.json.error]||'Could not complete the request. Refresh and retry.');return r.json;}catch(e){if(e.name==='AbortError')throw Error('Connection timed out. Refresh before retrying; a decision may already have been saved.');throw e;}finally{clearTimeout(timer);}}
 function navigation(){
  const isAdmin=ST.me?.role==='admin';document.querySelectorAll('[data-recovery-nav]').forEach(el=>{el.hidden=!isAdmin;el.disabled=!isAdmin;});
 }
 async function badge(){
  navigation();if(ST.me?.role!=='admin'||badgeBusy||Date.now()-badgeAt<60000)return;
  badgeBusy=true;badgeAt=Date.now();const owner=ST.me.id;
  try{const data=await api({action:'count'});if(ST.me?.id!==owner||ST.me.role!=='admin')return;document.querySelectorAll('[data-recovery-nav]').forEach(el=>{el.textContent='Password requests'+(data.pending?' ('+data.pending+')':'');});}
  catch{}finally{badgeBusy=false;}
 }
 function guardedDialog(title,body,save,label){
  dialog(title,body,save,label);const form=$('editForm'),editor=$('editor');if(!form)return;
  const submit=form.onsubmit;let busy=false;
  form.onsubmit=async event=>{event.preventDefault();if(busy)return;busy=true;const controls=[...form.querySelectorAll('input,button')].map(el=>[el,el.disabled]);controls.forEach(([el])=>el.disabled=true);const block=e=>e.preventDefault();editor.addEventListener('cancel',block);try{await submit(event);}finally{busy=false;controls.forEach(([el,disabled])=>el.disabled=disabled);editor.removeEventListener('cancel',block);}};
 }
 function review(row,approve){
  if(!approve){guardedDialog('Reject password request',`<p>Reject the request for <b>${esc(row.login)}</b>? Their password and account will stay as they are.</p>`,async()=>{await api({action:'review',id:row.id,decision:'rejected'});badgeAt=0;},'Reject request');return;}
  const confirmedName=row.profile?.full_name||row.login;
  guardedDialog(row.status==='approved'?'Create a reset link':'Approve password reset',`<p>Account: <b>${esc(confirmedName)}</b> · ${esc(row.login)}</p><p>Contact the student through a number or conversation you already trust. Details typed into a request are not proof of identity.</p><p>Registered phone: <b>${esc(row.registered_phone||'No registered phone available')}</b></p><label class="check"><input id="recoveryIdentity" type="checkbox">I confirmed this request with the actual student.</label><p class="hint">You will receive a private reset link to share with that student. Their password does not change until they use it.</p>`,async()=>{
   if(!$('recoveryIdentity').checked)throw Error(errors.identity_required);
   if(row.status!=='approved')await api({action:'review',id:row.id,decision:'approved',identity_confirmed:true});
   const data=await api({action:'issue',id:row.id,identity_confirmed:true});
   const url=new URL(data.reset_url);if(url.origin!=='https://math.portal.ghoneem.com'||url.pathname!=='/password-reset.html'||!url.hash.startsWith('#token_hash='))throw Error('Reset link unavailable. Try again.');
   lastLink={url:data.reset_url,name:confirmedName};badgeAt=0;
  },row.status==='approved'?'Create new reset link':'Approve & create reset link');
 }
 async function queue(){
  if(ST.me?.role!=='admin')throw Error(errors.forbidden);
  const n=++serial,selected=status,page=offset;
  const data=await api({action:'list',status:selected,offset:page});
  if(n!==serial||ST.view!=='passwordRecovery'||status!==selected||offset!==page)return;
  $('view').innerHTML=`<section class="recovery-queue"><div class="head"><h2>Password reset requests</h2><div class="sp"></div><a class="btn-sm" href="/password-recovery.html" target="_blank" rel="noopener">Open student form</a></div><p>Review requests from all groups. Confirm the student’s identity, then approve or reject. Approval lets you share a private reset link; students choose their own passwords.</p><div id="recoveryLinkArea"></div><div class="control-bar">${select('recoveryStatus','Show',[['pending','Waiting for approval'],['approved','Approved'],['rejected','Rejected']],status)}<button class="btn-sm" id="refreshRecovery">Refresh requests</button><button class="btn-sm" id="recoveryAccounts">Accounts & groups</button></div><p role="status">${Number(data.total)||0} ${esc(status)} request(s) · page ${Math.floor(offset/25)+1}</p>${data.items.length?data.items.map(row=>`<article class="recovery-request"><h3>${esc(row.profile?.full_name||row.full_name)} <span class="recovery-status">${esc(row.status)}</span></h3><dl><dt>Account login</dt><dd>${esc(row.login)}</dd><dt>Name supplied</dt><dd>${esc(row.full_name)}</dd><dt>Group supplied</dt><dd>${esc(row.group_note||'Not provided')}</dd><dt>Phone supplied</dt><dd>${esc(row.phone||'Not provided')}</dd><dt>Registered phone</dt><dd>${esc(row.registered_phone||'Not available — use your existing student contact')}</dd><dt>Account match</dt><dd>${row.profile?.role==='student'&&row.profile?.status==='active'?'Active student account':'No matching active student account'}</dd><dt>Requested</dt><dd>${esc(new Date(row.created_at).toLocaleString('en-GB',{timeZone:'Africa/Cairo'}))} Cairo</dd>${row.link_issued_at?`<dt>Last link created</dt><dd>${esc(new Date(row.link_issued_at).toLocaleString('en-GB',{timeZone:'Africa/Cairo'}))} Cairo</dd>`:''}</dl><div class="actions">${row.status!=='rejected'?`<button class="btn-sm" data-recovery-approve="${esc(row.id)}" ${!row.user_id||row.profile?.role!=='student'||row.profile?.status!=='active'?'disabled':''}>${row.status==='pending'?'Review & approve':'Create new reset link'}</button>`:''}${row.status==='pending'?`<button class="btn-sm danger" data-recovery-reject="${esc(row.id)}">Reject</button>`:''}</div></article>`).join(''):'<p class="empty">No '+esc(status)+' password reset requests.</p>'}<div class="actions"><button class="btn-sm" id="recoveryPrevious" ${offset===0?'disabled':''}>Previous</button><button class="btn-sm" id="recoveryNext" ${offset+25>=data.total?'disabled':''}>Next</button></div></section>`;
  if(lastLink){
   $('recoveryLinkArea').innerHTML=`<section class="recovery-link-panel" aria-label="Private reset link"><h3>Reset link for ${esc(lastLink.name)}</h3><p>Copy this link and share it privately using your existing contact with the student. It can be used once and expires. Do not open it yourself.</p><label for="privateResetLink">Private reset link</label><input id="privateResetLink" readonly><button class="btn-sm" id="copyResetLink">Copy reset link</button> <button class="btn-sm" id="hideResetLink">Hide link</button><p id="resetCopyMessage" role="status"></p></section>`;
   $('privateResetLink').value=lastLink.url;$('copyResetLink').onclick=async()=>{try{await navigator.clipboard.writeText(lastLink.url);$('resetCopyMessage').textContent='Copied. Share it privately with the verified student.';}catch{$('privateResetLink').select();$('resetCopyMessage').textContent='Select and copy the link above.';}};$('hideResetLink').onclick=()=>{lastLink=null;$('recoveryLinkArea').replaceChildren();};
  }
  $('recoveryStatus').onchange=()=>{status=val('recoveryStatus');offset=0;render();};$('refreshRecovery').onclick=()=>{badgeAt=0;render();};$('recoveryAccounts').onclick=()=>{ST.view='students';render();};$('recoveryPrevious').onclick=()=>{offset=Math.max(0,offset-25);render();};$('recoveryNext').onclick=()=>{offset+=25;render();};
  document.querySelectorAll('[data-recovery-approve]').forEach(b=>b.onclick=()=>review(data.items.find(r=>r.id===b.dataset.recoveryApprove),true));document.querySelectorAll('[data-recovery-reject]').forEach(b=>b.onclick=()=>review(data.items.find(r=>r.id===b.dataset.recoveryReject),false));
 }
 const priorSync=syncAdminNavigation;syncAdminNavigation=function(){navigation();return priorSync.apply(this,arguments);};
 const priorRender=render;render=async function(){
  navigation();if(ST.me&&!routeChecked){routeChecked=true;if(ST.me.role==='admin'&&location.hash==='#password-requests'){ST.view='passwordRecovery';history.replaceState(null,'',location.pathname+location.search);}}
  if(ST.view!=='passwordRecovery'){lastLink=null;const result=await priorRender.apply(this,arguments);void badge();return result;}
  syncAdminNavigation();$('view').innerHTML='<p role="status">Loading password requests…</p>';
  try{await queue();}catch(e){if(ST.view==='passwordRecovery'){$('view').innerHTML='<p role="alert" class="msg bad">'+esc(e.message)+'</p><button class="btn-sm" id="retryRecovery">Try again</button>';$('retryRecovery').onclick=()=>render();}}void badge();
 };
})();
