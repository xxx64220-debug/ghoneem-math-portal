(function(){
 'use strict';
 const $=id=>document.getElementById(id),form=$('registrationForm');
 const base='https://wfhurjyouemahvkcfkdz.supabase.co/functions/v1/student-registration';
 const headers={'Content-Type':'application/json',apikey:'sb_publishable_FIUSELOTsAQaH8dQ6oF-ow_CcISJV5-'};
 const messages={username_unavailable:'That username already has an account or request. Try signing in or contact your instructor; do not create another account.',registration_limit:'Too many requests from this connection. Please wait an hour or contact your instructor.',registration_unavailable:'Registration is temporarily unavailable. Retry with the same username and password.',invalid_details:'Please check your name, username and optional phone number.',weak_password:'Use a password of at least 8 characters (maximum 72 bytes).',invalid_track:'Reload the course list and choose an available course.',request_conflict:'This browser receipt belongs to another username. Reload and try again.'};
 let requestId='',lastUsername='',sending=false,loadingCourses=false;
 async function request(options={}){
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),20000);
  try{
   const r=await fetch(base,{headers,cache:'no-store',...options,signal:controller.signal});
   const data=await r.json().catch(()=>{throw Error('registration_unavailable');});
   if(!r.ok)throw Error(messages[data.error]?data.error:'registration_unavailable');
   return data;
  }catch(e){if(e.name==='AbortError'||e instanceof TypeError)throw Error('connection_interrupted');throw e;}
  finally{clearTimeout(timer);}
 }
 async function courses(){
  if(loadingCourses||sending)return;loadingCourses=true;
  $('retryCourses').hidden=true;$('course').disabled=true;$('submitRegistration').disabled=true;
  try{
   const data=await request();if(!Array.isArray(data.tracks)||!data.tracks.length)throw Error();
   $('course').replaceChildren(new Option('Choose your course',''),...data.tracks.map(t=>new Option(t.name,t.id)));
   $('course').disabled=false;$('submitRegistration').disabled=false;$('feedback').textContent='';
  }catch{
   $('course').replaceChildren(new Option('Courses unavailable',''));$('retryCourses').hidden=false;
   $('feedback').textContent='Could not load courses. Reload the list or try again shortly.';
  }finally{loadingCourses=false;}
 }
 $('retryCourses').onclick=courses;
 $('showPassword').onchange=()=>{for(const id of ['password','confirmPassword'])$(id).type=$('showPassword').checked?'text':'password';};
 form.onsubmit=async e=>{
  e.preventDefault();if(sending||loadingCourses||$('course').disabled||form.hidden)return;
  if(!form.reportValidity())return;$('feedback').textContent='';
  if($('password').value!==$('confirmPassword').value){$('feedback').textContent='Your passwords do not match.';$('confirmPassword').focus();return;}
  if(new TextEncoder().encode($('password').value).length>72){$('feedback').textContent=messages.weak_password;return;}
  const username=$('username').value.trim().toLowerCase();
  if(!requestId||lastUsername!==username){
   let old;try{old=JSON.parse(sessionStorage.getItem('registration-retry')||'null');}catch{}
   requestId=old?.username===username&&/^[0-9a-f-]{36}$/i.test(old.id||'')?old.id:crypto.randomUUID();
   try{sessionStorage.setItem('registration-retry',JSON.stringify({username,id:requestId}));}catch{}
   lastUsername=username;
  }
  const body={action:'submit',request_id:requestId,username,password:$('password').value,full_name:$('fullName').value.trim(),track_id:$('course').value,phone:$('phone').value.trim(),group_note:$('groupNote').value.trim(),website:$('website').value};
  sending=true;form.setAttribute('aria-busy','true');
  const controls=[...form.querySelectorAll('input,select,button')].map(el=>[el,el.disabled]);controls.forEach(([el])=>el.disabled=true);
  $('submitRegistration').textContent='Sending…';
  try{
   const data=await request({method:'POST',body:JSON.stringify(body)});
   if(data.submitted!==true)throw Error('registration_unavailable');
   $('password').value='';$('confirmPassword').value='';$('showPassword').checked=false;
   $('password').type=$('confirmPassword').type='password';
   form.hidden=true;$('success').hidden=false;$('successUsername').textContent='Your username: '+username;
   if(data.status==='approved')$('successMessage').textContent='Your request has already been approved. Sign in with the password you originally chose.';
   if(data.status==='rejected')$('successMessage').textContent='Your request was not approved. Contact your instructor before submitting another request.';
   $('success').focus();
  }catch(err){
   $('feedback').textContent=err.message==='connection_interrupted'?'Connection interrupted. Retry with the same username and password; an existing request will be kept.':messages[err.message]||messages.registration_unavailable;
   $('feedback').focus();
  }finally{
   body.password='';sending=false;form.removeAttribute('aria-busy');controls.forEach(([el,disabled])=>el.disabled=disabled);
   $('submitRegistration').textContent='Send registration request';
  }
 };courses();
})();
