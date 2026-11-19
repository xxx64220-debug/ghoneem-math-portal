(function(){
 'use strict';const $=id=>document.getElementById(id),form=$('recoveryRequestForm');let busy=false,receipt='',lastLogin='';
 const messages={recovery_limit:'Too many requests. Please wait an hour or contact your instructor.',invalid_details:'Check your username or email, name and phone number.',recovery_unavailable:'Could not confirm your request. Please retry; an existing request will be kept.'};
 form.onsubmit=async event=>{
  event.preventDefault();if(busy||form.hidden||!form.reportValidity())return;
  const login=$('recoveryLogin').value.trim().toLowerCase();
  if(!receipt||login!==lastLogin){receipt=crypto.randomUUID();lastLogin=login;}
  const body={action:'submit',request_id:receipt,login,full_name:$('recoveryName').value.trim(),phone:$('recoveryPhone').value.trim(),group_note:$('recoveryGroup').value.trim(),website:$('recoveryWebsite').value};
  busy=true;form.setAttribute('aria-busy','true');const controls=[...form.querySelectorAll('input,button')];controls.forEach(el=>el.disabled=true);$('recoverySubmit').textContent='Sending…';$('recoveryFeedback').textContent='';
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),15000);
  try{
   const r=await fetch('https://wfhurjyouemahvkcfkdz.supabase.co/functions/v1/password-recovery',{method:'POST',headers:{'Content-Type':'application/json',apikey:'sb_publishable_FIUSELOTsAQaH8dQ6oF-ow_CcISJV5-'},body:JSON.stringify(body),signal:controller.signal,cache:'no-store'});
   const data=await r.json();if(!r.ok||data.submitted!==true)throw Error(data.error||'recovery_unavailable');
   form.hidden=true;$('recoverySuccess').hidden=false;$('recoverySuccess').focus();
  }catch(e){$('recoveryFeedback').textContent=messages[e.message]||messages.recovery_unavailable;$('recoveryFeedback').focus();}
  finally{clearTimeout(timer);busy=false;controls.forEach(el=>el.disabled=false);form.removeAttribute('aria-busy');$('recoverySubmit').textContent='Send reset request';}
 };
})();
