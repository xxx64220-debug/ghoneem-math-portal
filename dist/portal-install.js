/* Installation only: does not access accounts, exams or stored answers. */
(() => {
  let pendingPrompt=null;
  const installed=()=>window.matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
  const buttons=[];
  const update=()=>buttons.forEach(button=>{button.hidden=installed();button.textContent=pendingPrompt?'Install app':'Install on your phone';});
  window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();pendingPrompt=event;update();});
  window.addEventListener('appinstalled',()=>{pendingPrompt=null;update();document.getElementById('portalInstallHelp')?.close();});
  const style=document.createElement('style');style.textContent='.portal-install-button{display:block;border:1px solid #14243e;border-radius:9px;background:#fff;color:#14243e;padding:11px 16px;margin-top:16px;font:600 14px/1.4 Inter,system-ui,sans-serif;min-height:44px;cursor:pointer}.portal-install-button[hidden]{display:none!important}header .portal-install-button{margin-top:0}#portalInstallHelp{margin:auto;width:min(440px,calc(100% - 28px));max-height:85vh;overflow:auto;border:1px solid #dededc;border-radius:14px;padding:24px;color:#14243e;background:#fff;font:16px/1.65 Inter,system-ui,sans-serif}#portalInstallHelp::backdrop{background:#14243e99}#portalInstallHelp h2{font-size:22px;margin:0 0 16px}#portalInstallHelp p{margin:12px 0}#portalInstallHelp button{background:#14243e;color:white;border:0;border-radius:8px;padding:11px 18px;min-height:44px;font:inherit}';document.head.append(style);
  function help(){
    let dialog=document.getElementById('portalInstallHelp');
    if(!dialog){dialog=document.createElement('dialog');dialog.id='portalInstallHelp';dialog.setAttribute('aria-labelledby','portalInstallTitle');dialog.innerHTML='<h2 id="portalInstallTitle">Install Ghoneem Math</h2><p><strong>Android</strong><br>Open this portal in Chrome. Tap the three-dot menu → Add to Home screen → Install.</p><p><strong>iPhone & iPad</strong><br>Open this portal in Safari. Tap Share → Add to Home Screen. Keep Open as Web App enabled if shown, then tap Add.</p><p>Your existing username and password still work. Internet is required for exams, saving answers and results.</p><form method="dialog"><button>Close</button></form>';document.body.append(dialog);}
    dialog.showModal();
  }
  async function install(){
    if(!pendingPrompt){help();return;}
    const event=pendingPrompt;pendingPrompt=null;
    try{await event.prompt();await event.userChoice;}catch{help();}finally{update();}
  }
  for(const target of [document.getElementById('vLogin'),document.querySelector('header.top .wrap')]){
    if(!target)continue;const button=document.createElement('button');button.type='button';button.className='portal-install-button';button.addEventListener('click',install);target.append(button);buttons.push(button);
  }
  update();
  if('serviceWorker'in navigator&&window.isSecureContext){navigator.serviceWorker.register('/portal-sw.js',{scope:'/'}).catch(()=>{/* Browser installation instructions remain available. */});}
})();
