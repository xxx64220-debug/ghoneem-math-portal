/* Staged TOTP pilot. Policy and authorization are enforced on the server. */
window.PortalMfa=(()=>{
 let cfg,active;
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const problem=e=>e?.status===429?'Too many attempts. Wait a minute before trying again.':'Verification failed. Check the code and your authenticator’s clock, then try again.';
 async function status(){const {data,error}=await cfg.sb.rpc('portal_mfa_status');if(error||!data)throw Error('verification_unavailable');return data;}
 function configure(value){cfg=value;const out=document.getElementById('outBtn');if(out&&!document.getElementById('securitySetupBtn')){const b=document.createElement('button');b.id='securitySetupBtn';b.textContent='Authenticator setup';b.hidden=true;b.onclick=()=>enroll().catch(()=>alert('Could not open authenticator setup. Try again later.'));out.before(b);status().then(p=>{b.hidden=!p.enrollment_allowed;}).catch(()=>{});}}
 async function ensure(fresh=false){
  const policy=await status();if(!policy.required)return true;
  const {data,error}=await cfg.sb.auth.mfa.getAuthenticatorAssuranceLevel();if(error)throw error;
  if(!fresh&&data.currentLevel==='aal2')return true;
  return challenge();
 }
 async function challenge(){
  if(active)return active;
  active=showChallenge().finally(()=>{active=null;});return active;
 }
 async function showChallenge(){
  const {data,error}=await cfg.sb.auth.mfa.listFactors();if(error)throw error;
  const factors=(data.totp||[]).filter(f=>f.status==='verified');
  const d=document.createElement('dialog');d.className='device-dialog';d.setAttribute('aria-label','Security verification');
  d.innerHTML=`<form class="device-panel"><h2>Security verification</h2><p>Enter the six-digit code from your authenticator app.</p>${factors.length?`<label>Authenticator<select name="factor">${factors.map(f=>`<option value="${esc(f.id)}">${esc(f.friendly_name||'Authenticator')}</option>`).join('')}</select></label><label>Verification code<input name="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required></label><button type="submit">Verify</button>`:'<p>No verified authenticator is available. Contact the portal owner for identity-checked recovery.</p>'}<p data-error role="alert"></p><p>Lost your authenticator? Use your backup authenticator or contact the portal owner. Password resets do not remove this check.</p><button type="button" data-cancel>Cancel</button></form>`;
  document.body.append(d);d.showModal();
  return new Promise(resolve=>{
   let busy=false,closed=false,nextTry=0;
   const finish=ok=>{if(closed)return;closed=true;d.querySelector('input')?.setAttribute('value','');const input=d.querySelector('input');if(input)input.value='';d.close();d.remove();resolve(ok);};
   d.oncancel=e=>{e.preventDefault();if(!busy)finish(false);};d.querySelector('[data-cancel]').onclick=()=>{if(!busy)finish(false);};
   d.querySelector('form').onsubmit=async e=>{
    e.preventDefault();if(busy||closed||!factors.length)return;
    const input=d.querySelector('[name=code]'),code=input.value.trim(),feedback=d.querySelector('[data-error]');
    if(!/^\d{6}$/.test(code)){feedback.textContent='Enter a six-digit code.';return;}
    if(Date.now()<nextTry){feedback.textContent='Please wait before trying again.';return;}
    busy=true;d.querySelectorAll('button').forEach(b=>b.disabled=true);
    try{const factorId=d.querySelector('select').value;const {error}=await cfg.sb.auth.mfa.challengeAndVerify({factorId,code});input.value='';if(error)throw error;
     const result=await cfg.sb.auth.mfa.getAuthenticatorAssuranceLevel();if(result.error||result.data.currentLevel!=='aal2')throw Error('verification_failed');finish(true);
    }catch(err){input.value='';nextTry=Date.now()+(err?.status===429?60000:2000);feedback.textContent=problem(err);}
    finally{busy=false;if(!closed)d.querySelectorAll('button').forEach(b=>b.disabled=false);}
   };
  });
 }
 async function enroll(){
  if(!await window.PortalDevices.reauthenticate())return;
  const policy=await status();if(!policy.enrollment_allowed)throw Error('enrollment_not_allowed');
  const {data,error}=await cfg.sb.auth.mfa.enroll({factorType:'totp',friendlyName:'Authenticator '+new Date().toISOString()});if(error)throw error;
  const factorId=data.id,d=document.createElement('dialog');d.className='device-dialog';d.setAttribute('aria-label','Set up authenticator');
  d.innerHTML='<form class="device-panel"><h2>Set up authenticator</h2><p>Add this setup key to your authenticator app. Keep a backup in a separate secure location. Do not share the key or codes.</p><code data-secret style="display:block;overflow-wrap:anywhere"></code><p>Setup can end other sign-in sessions. Do this only when you have no unfinished exam. Protection is pending administrator activation after testing.</p><label>Six-digit code<input name="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required></label><p data-error role="alert"></p><button type="submit">Verify setup</button><button type="button" data-cancel>Cancel</button></form>';
  d.querySelector('[data-secret]').textContent=data.totp.secret;document.body.append(d);d.showModal();
  let busy=false,verified=false,nextTry=0;
  async function close(){if(busy)return;d.querySelector('[data-secret]').textContent='';d.querySelector('input').value='';d.close();d.remove();if(!verified)await cfg.sb.auth.mfa.unenroll({factorId});}
  d.oncancel=e=>{e.preventDefault();close().catch(()=>{});};d.querySelector('[data-cancel]').onclick=()=>close().catch(()=>{});
  d.querySelector('form').onsubmit=async e=>{e.preventDefault();if(busy||Date.now()<nextTry)return;const input=d.querySelector('input');if(!/^\d{6}$/.test(input.value))return;busy=true;d.querySelectorAll('button').forEach(b=>b.disabled=true);
   try{const {error}=await cfg.sb.auth.mfa.challengeAndVerify({factorId,code:input.value});input.value='';if(error)throw error;verified=true;busy=false;await close();}
   catch(err){input.value='';nextTry=Date.now()+(err?.status===429?60000:2000);d.querySelector('[data-error]').textContent=problem(err);}
   finally{busy=false;d.querySelectorAll('button').forEach(b=>b.disabled=false);}
  };
 }
 return {configure,ensure,challenge,enroll};
})();
