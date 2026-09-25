/* Network-only. Never cache questions, sessions, exam attempts or API responses.
   No skipWaiting/clients.claim/reload: an update cannot interrupt an open exam. */
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET'||event.request.mode!=='navigate'||new URL(event.request.url).origin!==self.location.origin)return;
  event.respondWith(fetch(event.request).catch(()=>new Response('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ghoneem Math — connection needed</title></head><body style="font:18px/1.6 system-ui;padding:32px;color:#14243e"><h1>You’re offline</h1><p>Reconnect to the internet, then reload the portal. Exams and saving answers require a connection.</p><p><a href="/">Try again</a></p></body></html>',{status:503,headers:{'Content-Type':'text/html;charset=utf-8','Cache-Control':'no-store'}})));
});
