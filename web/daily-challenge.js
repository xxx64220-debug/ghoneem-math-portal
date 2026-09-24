// Daily checklist, five-question quiz and track-specific leaderboard.
let DAILY_DRAFT = {};
let DAILY_BUSY = false;

async function refreshMistakes() {
  const track = ST.track?.id;
  if (!track || DASH.mistakesLoading) return;
  DASH.mistakesLoading = true;
  DASH.mistakesError = '';
  if (DASH.view === 'mistakes' && !DASH.searchTerm?.trim()) paintDashboardContent();
  try {
    const {ok,json} = await fn('daily-challenge', {qs:`?track=${encodeURIComponent(track)}&view=notebook&offset=${DASH.mistakePage*25}`});
    if (!ok) throw new Error(friendly(json.error));
    if (ST.track?.id !== track) return;
    DASH.mistakes = json;
    if(json.remaining>0&&!json.items?.length&&DASH.mistakePage>0){DASH.mistakePage--;DASH.mistakesLoading=false;return refreshMistakes();}
  } catch (error) {
    if (ST.track?.id === track) DASH.mistakesError = error.message;
  } finally {
    DASH.mistakesLoading = false;
    if (ST.track?.id === track && DASH.view === 'mistakes' && !DASH.searchTerm?.trim()) paintDashboardContent();
  }
}

function mistakesPanel() {
  if (DASH.mistakesLoading || (!DASH.mistakes && !DASH.mistakesError))
    return '<section class="dash-panel"><h2>Mistake notebook</h2><p class="dash-empty" role="status">Loading your mistakes…</p></section>';
  if (DASH.mistakesError)
    return `<section class="dash-panel"><h2>Mistake notebook</h2><p class="dash-empty" role="alert">${esc(DASH.mistakesError)}</p><button class="btn" data-mistakes-retry>Try again</button></section>`;
  const items = DASH.mistakes?.items || [];
  const mastered=Object.values(DASH.notebookFeedback||{}).find(value=>value.mastered);
  const cards = items.map((item,index) => {
    const feedback=DASH.notebookFeedback?.[item.id];
    const choices=(item.choices||[]).map(c=>`<label class="daily-option"><input type="radio" name="notebook-${esc(item.id)}" value="${esc(c.key)}"><span><b>${esc(c.key)}.</b> ${esc(c.text)}</span></label>`).join('');
    return `<article class="mistake-card"><div class="dash-heading"><p class="mistake-meta">${esc(item.topic||'Practice question')}</p><span class="daily-tag">${item.streak}/2 correct in a row</span></div><h3>${esc(item.stem)}</h3>${typeof renderAssets==='function'?renderAssets(item.assets):''}<div class="daily-options">${item.type==='mcq'?choices:`<label class="field">Your answer<input class="gridin" data-notebook-text="${esc(item.id)}" autocomplete="off"></label>`}</div><button class="btn" data-notebook-submit="${esc(item.id)}">Check answer</button>${feedback?`<div class="mistake-explanation" role="status"><b>${feedback.correct?'Correct':'Try again'}</b><p>${esc(feedback.explanation||'')}</p><p>${feedback.mastered?'Mastered — two correct in a row.':`${feedback.streak}/2 correct in a row`}</p></div>`:''}</article>`;
  }).join('');
  const pages=Math.max(1,Math.ceil((DASH.mistakes.remaining||0)/25));
  return `<section class="dash-panel"><div class="dash-heading"><div><h2>Mistake notebook</h2><p class="dash-note">Wrong answers from reviewed exams and daily quizzes. Answer each one correctly twice in a row to master it; a wrong try resets the count.</p></div><span class="daily-tag">${DASH.mistakes.remaining} to practise · ${DASH.mistakes.mastered} mastered</span></div>${mastered?`<p class="dash-notice" role="status">Question mastered — two correct answers in a row. ${esc(mastered.explanation||'')}</p>`:''}${items.length?cards:'<div class="dash-empty">No mistakes to practise right now.</div>'}${pages>1?`<div class="history-pager"><button class="btn-ghost" data-notebook-page="prev" ${DASH.mistakePage===0?'disabled':''}>Previous</button><span>Page ${DASH.mistakePage+1} of ${pages}</span><button class="btn-ghost" data-notebook-page="next" ${DASH.mistakePage>=pages-1?'disabled':''}>Next</button></div>`:''}</section>`;
}

function wireMistakes() {
  document.querySelectorAll('[data-notebook-page]').forEach(button=>button.addEventListener('click',()=>{
    DASH.mistakePage+=button.dataset.notebookPage==='next'?1:-1;
    DASH.notebookFeedback={};DASH.mistakes=null;refreshMistakes();
  }));
  document.querySelector('[data-mistakes-retry]')?.addEventListener('click', () => {
    DASH.mistakesError='';
    refreshMistakes();
  });
  document.querySelectorAll('[data-notebook-submit]').forEach(button=>button.addEventListener('click',async()=>{
    const id=button.dataset.notebookSubmit, item=DASH.mistakes?.items?.find(q=>q.id===id);
    const answer=item?.type==='mcq'?document.querySelector(`input[name="notebook-${id}"]:checked`)?.value:document.querySelector(`[data-notebook-text="${id}"]`)?.value?.trim();
    if(!answer){button.insertAdjacentHTML('afterend','<p role="alert">Choose or enter an answer first.</p>');return;}
    button.disabled=true;
    try{
      const track=ST.track.id;
      const {ok,json}=await fn('daily-challenge',{method:'POST',body:{track,action:'notebook_answer',question_id:id,answer}});
      if(!ok)throw new Error(friendly(json.error));
      if(ST.track?.id!==track)return;
      DASH.notebookFeedback={ [id]:json };
      const state=await fn('daily-challenge',{qs:`?track=${encodeURIComponent(track)}&view=notebook&offset=${DASH.mistakePage*25}`});
      if(!state.ok)throw new Error(friendly(state.json.error));
      DASH.mistakes=state.json;
      if(DASH.view==='mistakes'&&!DASH.searchTerm?.trim())paintDashboardContent();
    }catch(error){button.disabled=false;button.insertAdjacentHTML('afterend',`<p role="alert">${esc(error.message)}</p>`);}
  }));
}

let DRILL_DRAFT={};
async function refreshDrill(){
  const track=ST.track?.id;if(!track)return;
  try{const {ok,json}=await fn('daily-challenge',{qs:`?track=${encodeURIComponent(track)}&view=drill`});
    if(!ok)throw new Error(friendly(json.error));if(ST.track?.id!==track)return;
    DASH.drill=json;DASH.drillError='';if(DASH.view==='drill'&&!DASH.searchTerm?.trim())paintDashboardContent();
  }catch(error){if(ST.track?.id===track){DASH.drillError=error.message;if(DASH.view==='drill'&&!DASH.searchTerm?.trim())paintDashboardContent();}}
}
function drillPanel(){
  const d=DASH.drill;
  if(!d)return `<section class="dash-panel"><h2>Weak-topic drill</h2><p class="dash-empty" role="status">${esc(DASH.drillError||'Loading your drill…')}</p>${DASH.drillError?'<button class="btn" data-drill-retry>Try again</button>':''}</section>`;
  const qs=d.questions||[];
  const cards=qs.map((q,i)=>{
    const selected=d.completed?q.submitted:DRILL_DRAFT[q.id];
    const options=(q.choices||[]).map(c=>`<label class="daily-option"><input type="radio" name="drill-${esc(q.id)}" value="${esc(c.key)}" data-drill-answer="${esc(q.id)}" ${selected===c.key?'checked':''} ${d.completed?'disabled':''}><span><b>${esc(c.key)}.</b> ${esc(c.text)}</span></label>`).join('');
    const feedback=d.completed?`<div class="daily-solution ${selected===q.answer?'right':'wrong'}"><b>${selected===q.answer?'Correct':`Correct answer: ${esc(q.answer)}`}</b><p>${esc(q.explanation||'')}</p></div>`:'';
    return `<fieldset class="daily-question"><legend><span class="daily-number">${i+1}</span> <span class="daily-stem">${esc(q.stem)}</span></legend><p class="dash-note">${esc(q.topic)}</p>${typeof renderAssets==='function'?renderAssets(q.assets):''}<div class="daily-options">${q.type==='mcq'?options:`<label class="field">Your answer<input class="gridin" data-drill-text="${esc(q.id)}" value="${esc(selected||'')}" ${d.completed?'disabled':''}></label>`}</div>${feedback}</fieldset>`;
  }).join('');
  return `<section class="dash-panel"><h2>Weak-topic drill</h2><p class="dash-note">An untimed set from your three lowest assessed topics. Your answers are graded together when you submit.</p>${d.drill_id?`<p class="dash-note">Topics: ${(d.topics||[]).map(esc).join(' · ')}</p>${d.completed?`<p class="dash-notice" role="status">${d.score}/${qs.length} correct. Review below, then start another set.</p>`:''}${cards}${d.completed?'<button class="btn" data-drill-start>Build another drill</button>':'<button class="btn" data-drill-submit>Submit drill</button><p id="drill-message" role="status"></p>'}`:'<button class="btn" data-drill-start>Build 15–18 questions</button><p id="drill-message" role="status"></p>'}</section>`;
}
function wireDrill(){
  document.querySelector('[data-drill-retry]')?.addEventListener('click',refreshDrill);
  document.querySelectorAll('[data-drill-answer]').forEach(input=>input.addEventListener('change',event=>DRILL_DRAFT[event.target.dataset.drillAnswer]=event.target.value));
  document.querySelectorAll('[data-drill-text]').forEach(input=>input.addEventListener('input',event=>DRILL_DRAFT[event.target.dataset.drillText]=event.target.value.trim()));
  document.querySelector('[data-drill-start]')?.addEventListener('click',async event=>{
    const button=event.currentTarget;button.disabled=true;
    try{const track=ST.track.id;const {ok,json}=await fn('daily-challenge',{method:'POST',body:{track,action:'drill_start'}});
      if(!ok)throw new Error(friendly(json.error));if(ST.track?.id!==track)return;
      DRILL_DRAFT={};DASH.drill=json;paintDashboard();
    }catch(error){button.disabled=false;const msg=document.getElementById('drill-message');if(msg)msg.textContent=error.message;}
  });
  document.querySelector('[data-drill-submit]')?.addEventListener('click',async event=>{
    const d=DASH.drill, qs=d?.questions||[];
    if(qs.some(q=>!DRILL_DRAFT[q.id])){document.getElementById('drill-message').textContent='Answer every question before submitting.';return;}
    const button=event.currentTarget;button.disabled=true;
    try{const track=ST.track.id;const {ok,json}=await fn('daily-challenge',{method:'POST',body:{track,action:'drill_submit',drill_id:d.drill_id,answers:Object.fromEntries(qs.map(q=>[q.id,DRILL_DRAFT[q.id]]))}});
      if(!ok)throw new Error(friendly(json.error));if(ST.track?.id!==track)return;
      DASH.drill=json;DRILL_DRAFT={};paintDashboard();
    }catch(error){button.disabled=false;const msg=document.getElementById('drill-message');if(msg)msg.textContent=error.message;}
  });
}

async function refreshDaily() {
  const track = ST.track?.id;
  if (!track) return;
  try {
    const { ok, json } = await fn('daily-challenge', { qs: `?track=${encodeURIComponent(track)}` });
    if (ST.track?.id !== track) return;
    if (!ok) throw new Error(friendly(json.error));
    json.receivedAt = Date.now();
    DASH.daily = json;
    DASH.dailyError = '';
    if (DASH.view === 'daily' && !DASH.searchTerm?.trim()) paintDashboardContent();
  } catch (error) {
    if (ST.track?.id === track) {
      DASH.dailyError = error.message;
      if (DASH.view === 'daily' && !DASH.searchTerm?.trim()) paintDashboardContent();
    }
  }
}


function streakRemaining(d, now = Date.now()) {
  const elapsed = now - (d.receivedAt || now);
  const clock = d.server_now ? Date.parse(d.server_now) + elapsed : now;
  const seconds = Math.max(0, Math.ceil((Date.parse(d.reset_at) - clock) / 1000));
  return { seconds, label: `${Math.floor(seconds/3600)}h ${Math.floor(seconds%3600/60)}m ${seconds%60}s` };
}

function streakPanel(d) {
  if (!d.streak) return '';
  const {current, longest, week} = d.streak;
  const next = [3,7,14,30].find(n => n > current);
  const message = d.completed ? 'Streak secured for today. Come back tomorrow!' : current > 0
    ? `Finish today’s quiz to keep your ${current}-day streak going.` : 'Finish today’s quiz to start your streak.';
  const days = (week || []).map(day => {
    const label = new Date(day.date+'T12:00:00Z').toLocaleDateString(undefined,{weekday:'short',timeZone:'Africa/Cairo'});
    const status = day.completed ? 'Complete' : day.today ? 'To do' : 'No quiz';
    return `<li class="streak-day ${day.completed?'is-complete':''} ${day.today?'is-today':''}" aria-label="${esc(day.date)}: ${status}"><span>${esc(label)}</span><b aria-hidden="true">${day.completed?'✓':day.today?'○':'—'}</b><small>${day.today?'Today':status}</small></li>`;
  }).join('');
  const badges = [3,7,14,30].map(n => `<li class="streak-badge ${longest>=n?'is-earned':''}"><span aria-hidden="true">${longest>=n?'🏅':'◇'}</span> ${n} days <small>${longest>=n?'Earned':'Locked'}</small></li>`).join('');
  return `<section class="dash-panel streak-panel" aria-labelledby="streak-title"><div class="streak-heading"><div><h2 id="streak-title">Your quiz streak</h2><p>${esc(ST.track?.theme?.label||d.track.toUpperCase())} · One completed quiz each day</p></div><div class="streak-best">Personal best <strong>${longest} ${longest===1?'day':'days'}</strong></div></div>
    <div class="streak-summary"><div class="streak-count"><span aria-hidden="true">🔥</span><strong>${current}</strong><span>day streak</span></div><div><p class="streak-message" role="status">${message}</p><p class="streak-deadline">${d.completed?'Next quiz in':'Time left today:'} <b data-streak-countdown>${streakRemaining(d).label}</b> · Midnight Cairo time</p>${!d.completed?'<a class="dash-link" href="#daily-quiz">Complete today’s quiz →</a>':''}</div></div>
    <ol class="streak-week" aria-label="Last seven days">${days}</ol><div class="streak-milestones"><h3>Streak badges</h3><p>${next?`${next-current} more consecutive ${next-current===1?'day':'days'} to the ${next}-day milestone.`:'30-day milestone reached. Keep your streak growing!'}</p><ul class="streak-badges">${badges}</ul></div><p class="dash-note">Any score counts after submitting all five answers. Missing a day resets your current streak; your best streak, earned badges and points stay. SAT and EST streaks are separate.</p></section>`;
}

function dailyPanel() {
  const d = DASH.daily;
  if (!d) return `<section class="dash-panel"><h2>Today's practice</h2><p class="dash-empty" role="status">${esc(DASH.dailyError || 'Loading your daily questions…')}</p>${DASH.dailyError ? '<button class="btn" data-daily-retry>Try again</button>' : ''}</section>`;
  const completed = d.completed;
  const checklist = [
    ['quiz', 'Finish the five-question quick quiz', 'One attempt per day; your answers are checked when you submit.'],
    ['focus', 'Practise a lesson to improve', 'Use your Lesson focus tab to pick a topic.'],
    ['review', 'Review one past mistake', 'Open an exam in Exam history and check the worked solution.'],
  ];
  const next = new Date(d.reset_at).toLocaleTimeString(undefined, {hour:'numeric',minute:'2-digit',timeZone:'Africa/Cairo'});
  const tasks = checklist.map(([id,label,description]) => {
    const done = d.checklist[id];
    return `<li class="daily-task ${done?'is-done':''}"><span class="daily-check" aria-hidden="true">${done?'✓':'○'}</span><div><strong>${label}</strong><p>${description}</p></div>${id==='quiz' ? (done ? '<span class="daily-tag">Done</span>' : '<a class="dash-link" href="#daily-quiz">Take quiz</a>') : `<button class="btn-ghost" data-daily-mark="${id}" ${done || DAILY_BUSY?'disabled':''}>${done?'Done':'Mark done'}</button>`}</li>`;
  }).join('');
  const questions = (d.quiz || []).map((q,i) => {
    const chosen = completed ? q.answer?.submitted : DAILY_DRAFT[q.id];
    const options = (q.choices||[]).map(c => `<label class="daily-option"><input type="radio" name="daily-${esc(q.id)}" value="${esc(c.key)}" data-daily-answer="${esc(q.id)}" ${chosen===c.key?'checked':''} ${completed?'disabled':''}><span><b>${esc(c.key)}.</b> ${esc(c.text)}</span></label>`).join('');
    const result = completed ? `<div class="daily-solution ${chosen===q.answer?.correct?'right':'wrong'}"><b>${chosen===q.answer?.correct?'Correct':'Correct answer: '+esc(q.answer?.correct||'—')}</b><p>${esc(q.answer?.explanation||'')}</p></div>` : '';
    return `<fieldset class="daily-question"><legend><span class="daily-number">${i+1}</span> <span class="daily-stem">${esc(q.stem)}</span></legend><p class="dash-note">${esc(q.topic||'Practice')}</p>${typeof renderAssets==='function'?renderAssets(q.assets):''}<div class="daily-options">${options}</div>${result}</fieldset>`;
  }).join('');
  const board = (d.leaderboard||[]).map(row => `<tr ${row.rank===d.rank?'class="my-rank"':''}><td>${row.rank}</td><td>${esc(row.name)}</td><td>${row.points}</td><td>${row.completed}</td></tr>`).join('');
  return `<div class="daily-top"><div><h2>Today's practice</h2><p>${new Date(d.date+'T12:00:00').toLocaleDateString(undefined,{weekday:'long',day:'numeric',month:'long',timeZone:'Africa/Cairo'})} · New questions every day at ${next} Cairo time</p></div><div class="daily-points"><strong>${d.points_total}</strong><span>total points · rank ${d.rank||'—'}</span></div></div>
  ${streakPanel(d)}
  <div class="dashboard-columns"><section class="dash-panel"><div class="dash-heading"><h2>Daily checklist</h2><span class="daily-tag">${Object.values(d.checklist).slice(0,3).filter(Boolean).length}/3 tasks</span></div><ul class="daily-tasks">${tasks}</ul><p class="dash-note">Quiz: 10 points for finishing + 10 per correct answer. Complete quizzes on consecutive days for a 5-point streak bonus. Finish your checklist for 5 more points.</p></section>
  <section class="dash-panel"><h2>${esc(ST.track?.theme?.label||ST.track?.id?.toUpperCase())} leaderboard</h2><p class="dash-note">Points earned in daily practice. Student names appear as first name and last initial.</p><div class="student-table"><table><thead><tr><th>Rank</th><th>Student</th><th>Points</th><th>Days</th></tr></thead><tbody>${board}</tbody></table></div>${d.rank>10?`<p class="dash-note">Your rank: ${d.rank} · ${d.points_total} points</p>`:''}</section></div>
  <section class="dash-panel" id="daily-quiz"><div class="dash-heading"><h2>Five-question quick quiz</h2><span class="daily-tag">${completed?`${d.score}/5 correct`:'One attempt today'}</span></div>${questions}${completed?'<p class="dash-notice">Great work. Tomorrow brings five new questions.</p>':`<button class="btn" data-daily-submit ${DAILY_BUSY?'disabled':''}>Submit answers</button><p class="dash-note">Answer all five before submitting. Your choices are final for today.</p>`}<p class="dash-note" id="daily-message" role="status"></p></section>`;
}

function dailyMessage(message) {
  const target = document.getElementById('daily-message');
  if (target) target.textContent = message;
}

function wireDaily() {
  document.querySelector('[data-daily-retry]')?.addEventListener('click', () => { DASH.dailyError=''; paintDashboard(); refreshDaily(); });
  document.querySelectorAll('[data-daily-answer]').forEach(radio => radio.addEventListener('change', event => {
    DAILY_DRAFT[event.target.dataset.dailyAnswer] = event.target.value;
  }));
  document.querySelectorAll('[data-daily-mark]').forEach(button => button.addEventListener('click', async () => {
    if (DAILY_BUSY) return;
    DAILY_BUSY = true; button.disabled = true;
    try {
      const {ok,json} = await fn('daily-challenge',{method:'POST',body:{track:ST.track.id,action:'mark',task:button.dataset.dailyMark}});
      if (!ok) throw new Error(friendly(json.error));
      json.receivedAt=Date.now(); DASH.daily=json; DAILY_BUSY=false; paintDashboard();
    } catch (error) { button.disabled=false; dailyMessage(error.message); }
    finally { DAILY_BUSY=false; }
  }));
  document.querySelector('[data-daily-submit]')?.addEventListener('click', async buttonEvent => {
    if (DAILY_BUSY) return;
    const questions = DASH.daily?.quiz||[];
    if (questions.some(q => !DAILY_DRAFT[q.id])) return dailyMessage('Choose an answer for all five questions.');
    const submitButton=buttonEvent.currentTarget;
    DAILY_BUSY=true; submitButton.disabled=true;
    try {
      const answers=Object.fromEntries(questions.map(q => [q.id,DAILY_DRAFT[q.id]]));
      const {ok,json}=await fn('daily-challenge',{method:'POST',body:{track:ST.track.id,action:'submit',answers}});
      if (!ok) throw new Error(friendly(json.error));
      json.receivedAt=Date.now(); DASH.daily=json; DAILY_DRAFT={}; DAILY_BUSY=false; paintDashboard();
      document.getElementById('daily-quiz')?.scrollIntoView({behavior:'smooth'});
    } catch(error) { submitButton.disabled=false; dailyMessage(error.message); }
    finally { DAILY_BUSY=false; }
  });
}

// Update only the timer text, preserving radio focus and answers.
let DAILY_REFRESHING = false;
function tickDailyStreak() {
  if (typeof ST === 'undefined' || !ST.track || !DASH.daily || document.visibilityState !== 'visible') return;
  const remaining = streakRemaining(DASH.daily);
  const timer = document.querySelector('[data-streak-countdown]');
  if (timer) timer.textContent = remaining.label;
  if (remaining.seconds === 0 && !DAILY_REFRESHING && !DAILY_BUSY) {
    DAILY_REFRESHING=true;
    DAILY_DRAFT={}; DASH.daily=null;
    if (DASH.view==='daily' && !DASH.searchTerm?.trim()) paintDashboardContent();
    refreshDaily().finally(() => { DAILY_REFRESHING=false; });
  }
}
setInterval(tickDailyStreak,1000);
document.addEventListener('visibilitychange',tickDailyStreak);
