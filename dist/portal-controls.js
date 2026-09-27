// Authenticated student feedback. Reports are stored for staff review.
function reportButton(questionId='',screen=''){
 return `<button type="button" class="dash-link report-question" data-report-question="${esc(questionId)}" data-report-screen="${esc(screen)}">${questionId?'Report question':'Report a problem'}</button>`;
}
function openPortalReport(questionId='',screen=''){
 const track=ST.track?.id;if(!track)return;
 let dialog=document.getElementById('portalReport');if(!dialog){dialog=document.createElement('dialog');dialog.id='portalReport';dialog.className='portal-report';document.body.appendChild(dialog);}
 const requestId=crypto.randomUUID();
 dialog.innerHTML=`<form id="portalReportForm"><h2>${questionId?'Report this question':'Report a site problem'}</h2><p>Your message goes to your instructor’s Reports tab.${questionId?' This question is attached automatically.':''}</p><label for="portalReportMessage">What should we check?</label><textarea id="portalReportMessage" minlength="10" maxlength="3000" required placeholder="For example: a missing diagram, an answer that seems wrong, or a button that does not work."></textarea><p id="portalReportStatus" role="status"></p><div class="report-actions"><button class="btn" id="portalReportSend">Send report</button><button type="button" class="btn-ghost" id="portalReportCancel">Cancel</button></div></form>`;
 document.getElementById('portalReportCancel').onclick=()=>dialog.close();
 document.getElementById('portalReportForm').onsubmit=async event=>{
  event.preventDefault();const message=document.getElementById('portalReportMessage').value.trim(),button=document.getElementById('portalReportSend'),status=document.getElementById('portalReportStatus'),input=document.getElementById('portalReportMessage'),cancel=document.getElementById('portalReportCancel');
  if(message.length<10){status.textContent='Please describe the problem in at least 10 characters.';return;}
  button.disabled=true;status.textContent='Sending…';
  try{const {ok,json}=await fn('portal-controls',{method:'POST',body:{action:'report',data:{track,kind:questionId?'question':'functionality',question_id:questionId||null,screen:screen||DASH.view||'portal',message,request_id:requestId}}});
   if(!ok)throw new Error(friendly(json.error));
   status.textContent='Report received. Your instructor can now review it.';input.disabled=true;button.hidden=true;cancel.textContent='Close';
  }catch(error){status.textContent=error.message;button.disabled=false;}
 };
 dialog.showModal();document.getElementById('portalReportMessage').focus();
}
document.addEventListener('click',event=>{
 const button=event.target.closest?.('[data-report-question]');if(button)openPortalReport(button.dataset.reportQuestion,button.dataset.reportScreen);
});
