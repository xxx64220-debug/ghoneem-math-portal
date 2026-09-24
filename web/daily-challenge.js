// Daily checklist, five-question quiz and track-specific leaderboard.
let DAILY_DRAFT = {};
let DAILY_BUSY = false;

async function refreshMistakes() {
  const track = ST.track?.id;
  if (!track || DASH.mistakesLoading) return;
  DASH.mistakesLoading = true;
  DASH.mistakesError = '';
  if (DASH.view === 'mistakes') paintDashboard();
  try {
    const {ok,json} = await fn('daily-challenge', {qs:`?track=${encodeURIComponent(track)}&view=mistakes`});
    if (!ok) throw new Error(friendly(json.error));
    if (ST.track?.id !== track) return;
    DASH.mistakes = json;
  } catch (error) {
    if (ST.track?.id === track) DASH.mistakesError = error.message;
  } finally {
    DASH.mistakesLoading = false;
    if (ST.track?.id === track && DASH.view === 'mistakes') paintDashboard();
  }
}

function mistakesPanel() {
  if (DASH.mistakesLoading || (!DASH.mistakes && !DASH.mistakesError))
    return '<section class="dash-panel"><h2>Wrong answers</h2><p class="dash-empty" role="status">Loading your quiz mistakes…</p></section>';
  if (DASH.mistakesError)
    return `<section class="dash-panel"><h2>Wrong answers</h2><p class="dash-empty" role="alert">${esc(DASH.mistakesError)}</p><button class="btn" data-mistakes-retry>Try again</button></section>`;
  const items = DASH.mistakes?.items || [];
  const cards = items.map((item,index) => {
    const options = (item.choices||[]).map(choice => {
      const classes = [choice.key===item.correct?'is-correct':'',choice.key===item.submitted?'is-submitted':''].filter(Boolean).join(' ');
      return `<li class="mistake-choice ${classes}"><b>${esc(choice.key)}.</b> ${esc(choice.text)}${choice.key===item.correct?' <span>Correct</span>':''}${choice.key===item.submitted&&choice.key!==item.correct?' <span>Your answer</span>':''}</li>`;
    }).join('');
    return `<article class="mistake-card"><div class="dash-heading"><p class="mistake-meta">${esc(item.topic||'Math')} · ${new Date(item.date+'T12:00:00').toLocaleDateString(undefined,{day:'numeric',month:'short',year:'numeric'})}</p><span class="daily-tag">Mistake ${index+1}</span></div><h3>${esc(item.stem)}</h3>${typeof renderAssets==='function'?renderAssets(item.assets):''}<ul class="mistake-choices">${options}</ul><div class="mistake-explanation"><b>Worked answer</b><p>${esc(item.explanation||'No explanation is available yet.')}</p></div></article>`;
  }).join('');
  return `<section class="dash-panel"><div class="dash-heading"><div><h2>Wrong answers</h2><p class="dash-note">Every question missed in the five-question daily quiz. Older mistakes stay here so you can review them again.</p></div><span class="daily-tag">${items.length} total</span></div>${items.length?cards:'<div class="dash-empty">No wrong quiz answers yet. Keep going!</div>'}</section>`;
}

function wireMistakes() {
  document.querySelector('[data-mistakes-retry]')?.addEventListener('click', () => {
    DASH.mistakesError='';
    refreshMistakes();
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
    if (DASH.view === 'daily') paintDashboard();
  } catch (error) {
    if (ST.track?.id === track) {
      DASH.dailyError = error.message;
      if (DASH.view === 'daily') paintDashboard();
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
    return `<fieldset class="daily-question"><legend><span class="daily-number">${i+1}</span> <span class="daily-stem">${esc(q.stem)}</span></legend><p class="dash-note">${esc(q.topic||'Math')}</p>${typeof renderAssets==='function'?renderAssets(q.assets):''}<div class="daily-options">${options}</div>${result}</fieldset>`;
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
    if (DASH.view==='daily') paintDashboard();
    refreshDaily().finally(() => { DAILY_REFRESHING=false; });
  }
}
setInterval(tickDailyStreak,1000);
document.addEventListener('visibilitychange',tickDailyStreak);
