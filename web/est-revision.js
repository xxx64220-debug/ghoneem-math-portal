(function(){
 'use strict';
 const C=ESTRevision,$=id=>document.getElementById(id);
 const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function render(){
  const track=C.track(new URLSearchParams(location.search).get('track')),course=C.courses[track],info=C.campaign(track);
  document.title='December '+course.name+' Revision · Ghoneem Math';
  $('courseTitle').textContent='December '+course.name+' revision.';
  $('courseEyebrow').textContent=course.name.toUpperCase()+' · DECEMBER 2026';
  $('courseIntro').textContent=course.intro;
  $('examDate').dateTime=course.examDate;$('examDate').textContent=course.dateLabel;
  $('examFormat').textContent=course.format;
  $('examCountdown').textContent=info.state==='finished'?'December exam completed':info.state==='exam'?'Today is exam day':info.days+' '+(info.days===1?'day':'days')+' to go';
  document.querySelectorAll('[data-course]').forEach(a=>{if(a.dataset.course===track)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');});
  document.querySelectorAll('[data-plan-link]').forEach(a=>{a.href='/study-plan.html?track='+track;});
  document.querySelectorAll('[data-activity]').forEach(a=>{a.href=C.activityLink(track,a.dataset.activity);});
  $('revisionStages').innerHTML=course.stages.map((stage,i)=>`<article class="card${info.phase===i?' is-current':''}"><div class="eyebrow">${escape(stage[1])}</div><h3>${escape(stage[2])}</h3>${info.phase===i?'<span class="badge current-phase">Current focus</span>':''}<p>${escape(stage[3])}</p></article>`).join('');
  $('campaignStatus').textContent=info.state==='finished'?'This December examination has finished. Review your progress and open your study plan for the next target.':info.state==='exam'?'Keep review light today. Check your admission ticket and exam arrangements, and allow time to arrive.':'Start with your assigned daily objectives. Add topic practice only within the time budget your instructor has set.';
  $('topicCards').innerHTML=course.topics.map(([title,lessons])=>`<article class="card"><h3>${escape(title)}</h3><ul>${lessons.map(lesson=>`<li><a href="${escape(C.activityLink(track,'practice',lesson))}">${escape(lesson)} →</a></li>`).join('')}</ul></article>`).join('');
  $('weeklyNote').hidden=track!=='est';
 }
 document.querySelectorAll('[data-course]').forEach(a=>a.addEventListener('click',event=>{if(event.button!==0||event.ctrlKey||event.metaKey||event.shiftKey||event.altKey)return;event.preventDefault();history.pushState(null,'',a.getAttribute('href'));render();}));
 window.addEventListener('popstate',render);
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)render();});
 render();
})();
