(function(){
 'use strict';const $=id=>document.getElementById(id),form=$('passwordResetForm');let token=new URLSearchParams(location.hash.slice(1)).get('token_hash')||'',verified=false,busy=false;
 history.replaceState(null,'',location.pathname+location.search);
 if(!/^[a-zA-Z0-9_-]{32,256}$/.test(token)||!globalThis.supabase){form.hidden=true;$('resetUnavailable').hidden=false;return;}
 // A separate memory-only session cannot overwrite an existing portal sign-in.
 async function boundedFetch(input,init){const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),15000);try{const r=await fetch(input,{...init,signal:controller.signal,cache:'no-store'});const bytes=await r.arrayBuffer();return new Response(bytes,{status:r.status,statusText:r.statusText,headers:r.headers});}finally{clearTimeout(timer);}}
 const client=supabase.createClient('https://wfhurjyouemahvkcfkdz.supabase.co','sb_publishable_FIUSELOTsAQaH8dQ6oF-ow_CcISJV5-',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false,storageKey:'ghoneem-password-reset'},global:{fetch:boundedFetch}});
 $('saveNewPassword').disabled=false;
 form.onsubmit=async event=>{
  event.preventDefault();if(busy||form.hidden||!form.reportValidity())return;
  let password=$('newPassword').value;
  if(password!==$('confirmNewPassword').value){$('resetFeedback').textContent='Your passwords do not match.';return;}
  if(password.length<8||new TextEncoder().encode(password).length>72){$('resetFeedback').textContent='Use at least 8 characters and no more than 72 bytes.';return;}
  busy=true;const controls=[...form.querySelectorAll('input,button')];controls.forEach(el=>el.disabled=true);$('resetFeedback').textContent='';form.setAttribute('aria-busy','true');
  try{
   if(!verified){
    const {data,error}=await client.auth.verifyOtp({token_hash:token,type:'recovery'});
    if(error||!data?.session){if(error?.status>=500||error?.name==='AuthRetryableFetchError')throw Error('connection');form.hidden=true;$('resetUnavailable').hidden=false;return;}
    verified=true;token='';
   }
   const {error}=await client.auth.updateUser({password});
   if(error){if(error.code==='weak_password'||error.code==='same_password'){ $('resetFeedback').textContent=error.code==='same_password'?'Choose a different password.':'Choose a stronger password with letters, numbers and symbols.';return;}throw Error('connection');}
   $('newPassword').value='';$('confirmNewPassword').value='';form.hidden=true;$('resetSuccess').hidden=false;$('resetSuccess').focus();
   // Revoke refresh sessions; the recovery client never persists credentials.
   await client.auth.signOut({scope:'global'}).catch(()=>{});
  }catch{$('resetFeedback').textContent=verified?'Could not confirm the save. Your password may have changed; try signing in with the new password. You can also retry here.':'Connection interrupted. Retry here. If the link was already used, ask your instructor for a new one.';}
  finally{password='';busy=false;controls.forEach(el=>el.disabled=false);form.removeAttribute('aria-busy');}
 };
})();
