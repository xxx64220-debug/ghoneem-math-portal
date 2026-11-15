/* Optional phone notifications, isolated from exam navigation and answer state. */
(() => {
 'use strict';
 const $n=id=>document.getElementById(id);
 let key=null,reg=null,current=null,revision=0,ready=false,busy=false,knownUser,activeUser=null;
 let cleanup=Promise.resolve();
 const actionIds=['pnEnable','pnSave','pnTest','pnOff'];
 const settingIds=['pnExams','pnResults','pnReminders'];
 // Storage can be blocked in private/restricted browsers. Server ownership remains authoritative.
 const owner={get(){try{return localStorage.getItem('portal-push-user');}catch{return null;}},set(id){try{if(id)localStorage.setItem('portal-push-user',id);else localStorage.removeItem('portal-push-user');}catch{}}};
 const stale=()=>new Error('Notification settings changed. Reopen this panel to try again.');
 function check(version){if(version!==revision)throw stale();}
 function invalidate(){revision++;ready=false;busy=false;current=null;key=null;activeUser=null;state();}
 const standalone=()=>matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
 const ios=()=>/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
 async function api(action,extra={}){
  const controller=new AbortController();
  try{
   const r=await bounded(fn('portal-notifications',{method:'POST',body:{action,...extra},signal:controller.signal}),10000,'Notification request timed out. Close and reopen settings to check before trying again.');
   if(!r.ok)throw new Error(r.json?.error||'Could not update notifications. Please try again.');return r.json;
  }finally{controller.abort();}
 }
 const supported=()=>window.isSecureContext&&'serviceWorker'in navigator&&'PushManager'in window&&'Notification'in window;
 async function registration(){
  if(!reg){await navigator.serviceWorker.register('/portal-sw.js',{scope:'/'});reg=await bounded(navigator.serviceWorker.ready,10000,'Finish any open exam, close all portal tabs, then reopen the portal to complete the notification update.');}
  await new Promise((resolve,reject)=>{
   const channel=new MessageChannel();const timer=setTimeout(()=>{channel.port1.close();reject(new Error('Finish any open exam, close all portal tabs, then reopen the portal to activate notifications.'));},3000);
   channel.port1.onmessage=e=>{clearTimeout(timer);channel.port1.close();e.data?.pushReady?resolve():reject(new Error('Reopen the portal to activate notifications.'));};
   reg.active?.postMessage({type:'portal-push-ready'},[channel.port2]);
  });
  return reg;
 }
 async function bounded(promise,ms,text){
  let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(text)),ms);})]);}finally{clearTimeout(timer);}
 }
 const existingRegistration=()=>navigator.serviceWorker.getRegistration('/');
 const bytes=s=>Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')+'='.repeat((4-s.length%4)%4)),c=>c.charCodeAt(0));
 const prefs=()=>({exams:$n('pnExams').checked,results:$n('pnResults').checked,reminders:$n('pnReminders').checked});
 function message(text){$n('pnStatus').textContent=text;}
 function state(){
  if(!$n('pnEnable'))return;
  $n('pnEnable').hidden=!!current;$n('pnSave').hidden=!current;$n('pnOff').hidden=!current;$n('pnTest').hidden=!current;
  for(const id of [...actionIds,...settingIds])$n(id).disabled=!ready||busy;
  $n('pnClose').disabled=busy;
 }
 async function stop(version){
  // Signing out must not install or activate a worker that the user never enabled.
  const r=await existingRegistration();check(version);const s=await r?.pushManager.getSubscription();check(version);
  if(s){
   const [server,browser]=await Promise.allSettled([api('unsubscribe',{endpoint:s.endpoint}),s.unsubscribe()]);
   if(server.status==='rejected'&&(browser.status==='rejected'||!browser.value))throw server.reason;
  }
  check(version);current=null;owner.set(null);
 }
 window.portalNotificationsBeforeLogout=async()=>{
  invalidate();const version=revision;
  if(supported()){try{await bounded(stop(version),3000,'Notification cleanup timed out.');}catch{/* Sign out must still work. */}}
 };
 async function open(){
  if(busy)return;
  let d=$n('portalNotifications');
  if(!d){
   d=document.createElement('dialog');d.id='portalNotifications';d.setAttribute('aria-labelledby','pnTitle');
   d.innerHTML='<h2 id="pnTitle">Phone notifications</h2><p id="pnIntro">Get portal announcements on this device. You can switch them off at any time.</p><div id="pnSettings"><label><input type="checkbox" id="pnExams" checked> New exams and practice</label><label><input type="checkbox" id="pnResults" checked> Results ready</label><label><input type="checkbox" id="pnReminders"> Daily practice reminder at 6 PM (Egypt)</label></div><p id="pnStatus" role="status" aria-live="polite"></p><div class="pn-actions"><button id="pnEnable" disabled>Enable notifications</button><button id="pnSave" hidden>Save preferences</button><button id="pnTest" hidden>Send me a test</button><button id="pnOff" hidden>Turn off on this device</button><button id="pnClose">Close</button></div>';
   document.body.append(d);$n('pnClose').onclick=()=>{invalidate();d.close();};
   d.oncancel=e=>{if(busy)e.preventDefault();else invalidate();};
   for(const id of actionIds)$n(id).onclick=async()=>{
    if(!ready||busy)return;const version=revision;busy=true;state();
    try{
     if(id==='pnOff'){await stop(version);message('Notifications are off on this device.');}
     else if(id==='pnTest'){await api('test',{endpoint:current.endpoint});check(version);message('Test queued. It usually arrives within a minute.');}
     else{
      // Permission is requested directly from this tap, required by iOS.
      if(Notification.permission!=='granted'){
       const permission=await Notification.requestPermission();
       check(version);
       if(permission!=='granted')throw new Error(permission==='denied'?'Notifications are blocked. Allow them in your browser or phone notification settings, then try again.':'Notifications were not enabled. You can try again whenever you are ready.');
      }
      const r=await registration();check(version);let s=await r.pushManager.getSubscription();check(version);const created=!s;
      if(!s)s=await r.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:bytes(key)});
      try{check(version);await api('subscribe',{subscription:s.toJSON(),preferences:prefs()});check(version);}catch(e){if(created)await s.unsubscribe().catch(()=>{});throw e;}
      current=s;owner.set(activeUser);
      state();message('Notifications enabled on this device. Preferences saved.');
     }
    }catch(e){if(version===revision)message(e.message);}finally{if(version===revision){busy=false;state();}}
   };
  }
  invalidate();const version=revision;if(!d.open)d.showModal();message('Checking notification settings…');
  if(ios()&&!standalone()){message('On iPhone or iPad, first add this portal to your Home Screen, then open the installed app and enable notifications here.');$n('pnEnable').disabled=true;return;}
  if(!supported()){message('This browser does not support push notifications. Try Chrome on Android, or the installed Home Screen app on iPhone (iOS 16.4 or later).');return;}
  try{
   await cleanup;check(version);
   const {data:{session},error}=await sb.auth.getSession();check(version);
   if(error||!session)throw new Error('Sign in to manage notifications on this device.');
   activeUser=session.user.id;knownUser=activeUser;
   const config=await api('config');check(version);key=config.publicKey;
   const r=await existingRegistration();check(version);let subscription=await r?.pushManager.getSubscription();check(version);
   const previousOwner=owner.get();
   if(subscription&&previousOwner&&previousOwner!==activeUser){await subscription.unsubscribe();check(version);subscription=null;owner.set(null);}
   if(subscription){const data=await api('status',{endpoint:subscription.endpoint});check(version);if(data.subscription){for(const [id,k]of [['pnExams','exams'],['pnResults','results'],['pnReminders','reminders']])$n(id).checked=data.subscription[k];owner.set(activeUser);}else{await subscription.unsubscribe();check(version);subscription=null;owner.set(null);}}
   current=subscription||null;ready=true;state();message(current?'Notifications are enabled on this device.':'Notifications are off. Tap Enable notifications to allow them.');
  }catch(e){if(version===revision){current=null;ready=false;state();message(e.message);}}
 }
 const style=document.createElement('style');style.textContent='#portalNotifications{margin:auto;width:min(480px,calc(100% - 24px));max-height:85vh;overflow:auto;border:1px solid #dededc;border-radius:14px;padding:24px;color:#14243e;background:white;font:16px/1.6 Inter,system-ui,sans-serif}#portalNotifications::backdrop{background:#14243e99}#portalNotifications h2{margin-top:0}#portalNotifications label{display:flex;align-items:center;gap:10px;margin:14px 0}#portalNotifications input{width:20px;height:20px;flex-shrink:0}#portalNotifications button{border:1px solid #14243e;border-radius:8px;padding:10px 14px;min-height:44px;background:#14243e;color:white;font:inherit;cursor:pointer}#portalNotifications button:disabled{opacity:.55}#portalNotifications [hidden]{display:none!important}.pn-actions{display:flex;gap:8px;flex-wrap:wrap}#pnStatus{font-size:14px}';document.head.append(style);
 const target=document.querySelector('header.top .wrap');if(target){const b=document.createElement('button');b.type='button';b.className='btn-sm';b.textContent='Notifications';b.onclick=open;target.append(b);}
 // Clean up stale local subscriptions when a different account signs in here.
 sb.auth.onAuthStateChange((event,session)=>{
  if(!['SIGNED_IN','SIGNED_OUT','INITIAL_SESSION'].includes(event))return;
  const nextUser=session?.user.id||null,previousOwner=owner.get();
  const changed=knownUser!==undefined&&knownUser!==nextUser;knownUser=nextUser;
  if(changed||event==='SIGNED_OUT'||(previousOwner&&previousOwner!==nextUser)){
   invalidate();if($n('portalNotifications')?.open)message('Your sign-in changed. Close and reopen notification settings.');
   if(supported())cleanup=cleanup.then(()=>existingRegistration()).then(r=>r?.pushManager.getSubscription()).then(s=>s?.unsubscribe()).catch(()=>{});
   owner.set(null);
  }
 });
})();
