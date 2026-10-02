// Exam renderer at 2c239765, retained to assert unchanged math markup.
function renderQ() {
  const q = ST.run.questions[ST.idx];
  let body;
  if (q.type === 'mcq') {
    body = (q.choices || []).map(c => `<button class="choice ${q.response === c.key ? 'sel' : ''}"
      data-k="${esc(c.key)}"><span class="k">${esc(c.key)}</span><span class="choice-text">${esc(c.text)}</span></button>`).join('');
  } else {
    body = `<input class="gridin" id="gin" inputmode="text" autocomplete="off"
      placeholder="Your answer" value="${esc(q.response ?? '')}">
      <div class="gridin-hint">Fractions and decimals are both accepted — 3/4 or 0.75.</div>`;
  }
  $('qcard').innerHTML = `<div class="qhead"><span class="qnum">QUESTION ${ST.idx + 1}</span>
    <span class="qnum" style="color:var(--accent)">${esc(q.topic || '')}</span></div>
    ${ST.run.exam?.track_id==='est'?'<p class="dash-note" style="margin-bottom:14px"><a href="/exams/est-march-2026/reference.png" target="_blank" rel="noopener">Formula reference ↗</a></p>':''}
    <div class="stem">${esc(q.stem)}</div>${figure(q.assets)}${body}${reportButton(q.id,'exam question')}`;
  math($('qcard'));

  $('qcard').querySelectorAll('.choice').forEach(b =>
    b.onclick = () => save(q, b.dataset.k));
  const gin = $('gin');
  if (gin) {
    gin.oninput = () => save(q, gin.value.trim());
  }
  $('prevBtn').disabled = ST.idx === 0;
  $('nextBtn').disabled = ST.idx === ST.run.questions.length - 1;
  $('flagBtn').textContent = ST.flags.has(q.id) ? 'Unflag' : 'Flag';
}

