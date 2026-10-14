/* Network-only. Never cache questions, sessions, exam attempts or API responses.
   No skipWaiting/clients.claim/reload: an update cannot interrupt an open exam. */
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET'||event.request.mode!=='navigate'||new URL(event.request.url).origin!==self.location.origin)return;
  event.respondWith(fetch(event.request).catch(()=>new Response('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ghoneem Math — connection needed</title></head><body style="font:18px/1.6 system-ui;padding:32px;color:#14243e"><h1>You’re offline</h1><p>Reconnect to the internet, then reload the portal. Exams and saving answers require a connection.</p><p><a href="/">Try again</a></p></body></html>',{status:503,headers:{'Content-Type':'text/html;charset=utf-8','Cache-Control':'no-store'}})));
});

self.addEventListener('push',event=>{
 let data={};try{data=event.data?.json()||{};}catch{}
 // Always show a visible message; no exam answers or scores in push payloads.
 event.waitUntil(self.registration.showNotification(String(data.title||'Ghoneem Math').slice(0,80),{
  body:String(data.body||'Open the portal for an update.').slice(0,240),icon:'/icons/portal-192.png',
  tag:String(data.tag||'portal-update').slice(0,200),data:{url:'/'},
 }));
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();event.waitUntil((async()=>{
  const tabs=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  const existing=tabs.find(c=>new URL(c.url).origin===self.location.origin);
  // Focus an open portal without navigating: never interrupt an active exam.
  if(existing)return existing.focus();return self.clients.openWindow('/');
 })());
});

self.addEventListener('message',event=>{if(event.data?.type==='portal-push-ready')event.ports[0]?.postMessage({pushReady:true});});
