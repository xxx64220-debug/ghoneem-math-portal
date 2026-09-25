/* Optional phone notifications, isolated from exam navigation and answer state. */
(() => {
 'use strict';
 const $n=id=>document.getElementById(id);
 let key=null,reg=null,current=null;
 const standalone=()=>matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
 const ios=()=>/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
 async function api(action,extra={}){
  const r=await fn('portal-notifications',{method:'POST',body:{action,...extra}});
  if(!r.ok)throw new Error(r.json.error||'Could not update notifications. Please try again.');return r.json;
 }
 const supported=()=>window.isSecureContext&&'serviceWorker'in navigator&&'PushManager'in window&&'Notification'in window;
 async function registration(){
  if(!reg){await navigator.serviceWorker.register('/portal-sw.js',{scope:'/'});reg=await Promise.race([navigator.serviceWorker.ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Finish any open exam, close all portal tabs, then reopen the portal to complete the notification update.')),10000))]);}
  await new Promise((resolve,reject)=>{
   const channel=new MessageChannel();const timer=setTimeout(()=>{channel.port1.close();reject(new Error('Finish any open exam, close all portal tabs, then reopen the portal to activate notifications.'));},3000);
   channel.port1.onmessage=e=>{clearTimeout(timer);channel.port1.close();e.data?.pushReady?resolve():reject(new Error('Reopen the portal to activate notifications.'));};
   reg.active?.postMessage({type:'portal-push-ready'},[channel.port2]);
  });
  return reg;
 }
 const bytes=s=>Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')+'='.repeat((4-s.length%4)%4)),c=>c.charCodeAt(0));
 const prefs=()=>({exams:$n('pnExams').checked,results:$n('pnResults').checked,reminders:$n('pnReminders').checked});
 function message(text){$n('pnStatus').textContent=text;}
 function state(){
  $n('pnEnable').hidden=!!current;$n('pnSave').hidden=!current;$n('pnOff').hidden=!current;$n('pnTest').hidden=!current;
 }
 async function stop(){
  const r=await registration();const s=await r.pushManager.getSubscription();
  if(s){let serverError;try{await api('unsubscribe',{endpoint:s.endpoint});}catch(e){serverError=e;}const stopped=await s.unsubscribe();if(!stopped&&serverError)throw serverError;}
  current=null;localStorage.removeItem('portal-push-user');
  if($n('pnStatus')){state();message('Notifications are off on this device.');}
 }
 window.portalNotificationsBeforeLogout=async()=>{if(supported()){try{await stop();}catch{/* Sign out must still work; revoked session cannot change preferences. */}}};
 async function open(){
  let d=$n('portalNotifications');
  if(!d){
   d=document.createElement('dialog');d.id='portalNotifications';d.setAttribute('aria-labelledby','pnTitle');
   d.innerHTML='<h2 id="pnTitle">Phone notifications</h2><p id="pnIntro">Get portal announcements on this device. You can switch them off at any time.</p><div id="pnSettings"><label><input type="checkbox" id="pnExams" checked> New exams and practice</label><label><input type="checkbox" id="pnResults" checked> Results ready</label><label><input type="checkbox" id="pnReminders"> Daily practice reminder at 6 PM (Egypt)</label></div><p id="pnStatus" role="status" aria-live="polite"></p><div class="pn-actions"><button id="pnEnable" disabled>Enable notifications</button><button id="pnSave" hidden>Save preferences</button><button id="pnTest" hidden>Send me a test</button><button id="pnOff" hidden>Turn off on this device</button><button id="pnClose">Close</button></div>';
   document.body.append(d);$n('pnClose').onclick=()=>d.close();
   for(const id of ['pnEnable','pnSave','pnTest','pnOff'])$n(id).onclick=async()=>{
    const b=$n(id);b.disabled=true;
    try{
     if(id==='pnOff')await stop();
     else if(id==='pnTest'){await api('test',{endpoint:current.endpoint});message('Test queued. It usually arrives within a minute.');}
     else{
      // Permission is requested directly from this tap, required by iOS.
      if(Notification.permission!=='granted'){
       const permission=await Notification.requestPermission();
       if(permission!=='granted')throw new Error(permission==='denied'?'Notifications are blocked. Allow them in your browser or phone notification settings, then try again.':'Notifications were not enabled. You can try again whenever you are ready.');
      }
      const r=await registration();let s=await r.pushManager.getSubscription();const created=!s;
      if(!s)s=await r.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:bytes(key)});
      try{await api('subscribe',{subscription:s.toJSON(),preferences:prefs()});}catch(e){if(created)await s.unsubscribe();throw e;}
      current=s;const {data:{session}}=await sb.auth.getSession();if(session)localStorage.setItem('portal-push-user',session.user.id);
      state();message('Notifications enabled on this device. Preferences saved.');
     }
    }catch(e){message(e.message);}finally{b.disabled=false;}
   };
  }
  d.showModal();message('Checking notification settings…');
  if(ios()&&!standalone()){message('On iPhone or iPad, first add this portal to your Home Screen, then open the installed app and enable notifications here.');$n('pnEnable').disabled=true;return;}
  if(!supported()){message('This browser does not support push notifications. Try Chrome on Android, or the installed Home Screen app on iPhone (iOS 16.4 or later).');return;}
  try{
   key=(await api('config')).publicKey;const r=await registration();current=await r.pushManager.getSubscription();
   const {data:{session}}=await sb.auth.getSession();const owner=localStorage.getItem('portal-push-user');
   if(current&&owner&&owner!==session?.user.id){await current.unsubscribe();current=null;localStorage.removeItem('portal-push-user');}
   if(current){const data=await api('status',{endpoint:current.endpoint});if(data.subscription){for(const [id,k]of [['pnExams','exams'],['pnResults','results'],['pnReminders','reminders']])$n(id).checked=data.subscription[k];}else{await current.unsubscribe();current=null;}}
   state();$n('pnEnable').disabled=false;message(current?'Notifications are enabled on this device.':'Notifications are off. Tap Enable notifications to allow them.');
  }catch(e){message(e.message);}
 }
 const style=document.createElement('style');style.textContent='#portalNotifications{margin:auto;width:min(480px,calc(100% - 24px));max-height:85vh;overflow:auto;border:1px solid #dededc;border-radius:14px;padding:24px;color:#14243e;background:white;font:16px/1.6 Inter,system-ui,sans-serif}#portalNotifications::backdrop{background:#14243e99}#portalNotifications h2{margin-top:0}#portalNotifications label{display:flex;align-items:center;gap:10px;margin:14px 0}#portalNotifications input{width:20px;height:20px;flex-shrink:0}#portalNotifications button{border:1px solid #14243e;border-radius:8px;padding:10px 14px;min-height:44px;background:#14243e;color:white;font:inherit;cursor:pointer}#portalNotifications button:disabled{opacity:.55}#portalNotifications [hidden]{display:none!important}.pn-actions{display:flex;gap:8px;flex-wrap:wrap}#pnStatus{font-size:14px}';document.head.append(style);
 const target=document.querySelector('header.top .wrap');if(target){const b=document.createElement('button');b.type='button';b.className='btn-sm';b.textContent='Notifications';b.onclick=open;target.append(b);}
 // Clean up stale local subscriptions when a different account signs in here.
 sb.auth.onAuthStateChange((event,session)=>{
  const owner=localStorage.getItem('portal-push-user');
  if(supported()&&owner&&(!session||owner!==session.user.id)&&['SIGNED_IN','SIGNED_OUT','INITIAL_SESSION'].includes(event)){
   navigator.serviceWorker.getRegistration('/').then(r=>r?.pushManager.getSubscription()).then(s=>s?.unsubscribe()).catch(()=>{});localStorage.removeItem('portal-push-user');current=null;
  }
 });
})();
