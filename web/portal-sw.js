/* Cache only a public offline shell. Never cache accounts, answers, questions or APIs.
   No skipWaiting/clients.claim/reload: updates cannot interrupt an open exam. */
const SHELL_CACHE='ghoneem-shell-20261114-ui';
const SHELL_FILES=['/offline.html','/portal-ui.css?v=20261114-ui','/icons/portal-192.png','/icons/portal-512.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(SHELL_CACHE).then(cache=>cache.addAll(SHELL_FILES))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('ghoneem-shell-')&&key!==SHELL_CACHE).map(key=>caches.delete(key))))));
self.addEventListener('fetch',event=>{
 const request=event.request,url=new URL(request.url);
 if(request.method!=='GET'||url.origin!==self.location.origin)return;
 if(request.mode==='navigate')event.respondWith(fetch(request).catch(async()=>await caches.match('/offline.html')||new Response('Reconnect to open Ghoneem Math.',{status:503,headers:{'Content-Type':'text/plain'}})));
 else if(SHELL_FILES.includes(url.pathname+url.search))event.respondWith(fetch(request).catch(()=>caches.match(request)));
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
