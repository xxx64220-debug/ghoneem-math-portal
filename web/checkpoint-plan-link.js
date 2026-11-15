/* Navigation only: use the current planner selection without extra database work. */
(()=>{
 'use strict';
 const host=document.getElementById('checkpointLink');if(!host)return;
 function sync(){
  host.replaceChildren();host.hidden=true;
  if(typeof ready==='undefined'||!ready||loading||!me)return;
  const track=$('track').value,date=$('date').value;
  if(!['sat','est','est2','act2'].includes(track)||!date)return;
  const selected=staff?selectedUsers():[{user_id:me.id}];if(!selected.length)return;
  const params=new URLSearchParams({track,date,mode:'objectives'});
  if(staff&&$('group').value)params.set('group',$('group').value);
  if(staff&&selected.length===1)params.set('student',selected[0].user_id);
  const a=document.createElement('a');a.textContent=staff&&selected.length>1?'Group checkpoints · progress & next practice →':'Checkpoint · results & next practice →';
  a.href='/checkpoint.html?'+params;host.append(a);host.hidden=false;
 }
 document.addEventListener('study-plan-view',sync);
 document.getElementById('workspace')?.addEventListener('change',()=>{if(loading)host.hidden=true;});
 sync();
})();
