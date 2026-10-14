// The bank is read through the existing staff RLS client. Paging never drops
// selections and the ordered Set is the exact order sent to exam.save.
function examPickerModel(questions, initialIds = [], track = '') {
  const byId = new Map(questions.map(q => [q.id, q]));
  const selected = new Set(initialIds);
  return {
    questions, byId, selected, track, search: '', topic: '', difficulty: '', type: '',
    selectedOnly: false, page: 0, pageSize: 25,
    matches() {
      const words = this.search.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
      const pool = this.selectedOnly ? [...selected].map(id => byId.get(id)).filter(Boolean) : questions;
      return pool.filter(q => q.track_id === this.track && (this.selectedOnly || (
        (!this.topic || q.topic === this.topic) && (!this.difficulty || q.difficulty === this.difficulty) &&
        (!this.type || q.type === this.type) && words.every(word =>
          [q.topic, q.assets?.lesson_subtopic, q.stem, q.assets?.source_code, q.assets?.source_question_id, q.assets?.source_document, q.id].join(' ').toLocaleLowerCase().includes(word))
      )));
    },
    pageData() {
      const matches = this.matches(), pages = Math.max(1, Math.ceil(matches.length / this.pageSize));
      this.page = Math.max(0, Math.min(this.page, pages - 1));
      const start = this.page * this.pageSize;
      return { total: matches.length, pages, start, rows: matches.slice(start, start + this.pageSize) };
    },
    toggle(id, checked) {
      const q = byId.get(id);
      if (!q || q.track_id !== this.track || (checked && (q.assets?.release_hold_reason || (!selected.has(id) && selected.size >= 200)))) return;
      checked ? selected.add(id) : selected.delete(id);
    },
    move(id, delta) {
      const ids = [...selected], index = ids.indexOf(id), next = index + delta;
      if (index < 0 || next < 0 || next >= ids.length) return;
      [ids[index], ids[next]] = [ids[next], ids[index]];
      selected.clear(); ids.forEach(id => selected.add(id));
    },
    changeTrack(value) { this.track = value; this.topic = ''; this.page = 0; selected.clear(); }
  };
}

function examQuestionPreview(q) {
  return `<div class="builder-preview"><div class="builder-stem">${esc(q.stem)}</div>${figure(q.assets)}
    ${q.type === 'mcq' ? `<ol class="builder-choices">${(q.choices || []).map(c => `<li><b>${esc(c.key)}.</b> ${esc(c.text)}</li>`).join('')}</ol>` : '<p class="hint">Numeric answer</p>'}
    ${q.assets?.release_hold_reason ? `<p class="builder-warning">${esc(q.assets.release_hold_reason)}</p>` : ''}
    <p class="hint">${esc(q.assets?.source_code || q.assets?.source_question_id || q.id)}</p></div>`;
}

function questionHoldLabel(q) {
  return /duplicate/i.test(q.assets?.release_hold_reason || '') ? 'Duplicate' : 'Needs review';
}

function renderQuestionMath(el) {
  if (window.renderMathInElement) window.renderMathInElement(el, {delimiters:[{left:'$$',right:'$$',display:true},{left:'\\[',right:'\\]',display:true},{left:'\\(',right:'\\)',display:false},{left:'$',right:'$',display:false}],throwOnError:false});
}

async function editExam(x = {}, initialQuestionIds = []) {
  let questions = [], model;
  const track = x.track_id || ST.track || ST.tracks[0]?.id || '';
  // Open the dialog before the paginated bank read. A slow read otherwise
  // makes Create exam look unresponsive, especially for larger question banks.
  dialog(x.id ? 'Edit exam' : 'Create exam',
    '<p id="examBuilderLoading" class="hint" role="status">Loading the question bank…</p>', async () => {
      if (!model) throw new Error('The question bank is still loading. Please wait.');
      if (!val('etitle')) throw new Error('Enter an exam title.');
      const minutes = Number(val('emins'));
      if (!Number.isFinite(minutes) || minutes < 1 || minutes > 240) throw new Error('Enter a duration between 1 and 240 minutes.');
      if (!model.selected.size || model.selected.size > 200) throw new Error('Select between 1 and 200 questions.');
      if ([...model.selected].some(id => !model.byId.has(id) || model.byId.get(id).track_id !== model.track)) throw new Error('Some selected questions are unavailable in this track. Reopen the exam after checking access.');
      await mutation('exam.save', {id:x.id,track_id:model.track,title:val('etitle'),duration_seconds:Math.round(minutes*60),question_ids:[...model.selected],is_full_length:val('etype')==='full_exam',assessment_type:val('etype'),scoring_map:jval('emap'),review_policy:val('ereview'),is_published:x.is_published||false});
    }, 'Save exam');
  const editor = $('editor');
  editor.classList.add('exam-builder');
  editor.addEventListener('close', () => editor.classList.remove('exam-builder'), {once:true});
  $('editSave').disabled = true;
  let loading = $('examBuilderLoading');
  try { questions = await getRows('questions', false, '*', 'id', 'track_id', track); }
  catch (e) {
    if (editor.open === false) return;
    loading.textContent = 'Could not load the question bank. ' + e.message;
    loading.setAttribute('role','alert');
    return;
  }
  if (editor.open === false) return;
  model = examPickerModel(questions, x.question_ids?.length ? x.question_ids : initialQuestionIds, track);
  const expanded = new Set();
  let trackLoad = 0;
  const button = (id, text) => `<button type="button" class="btn-sm" id="${id}">${text}</button>`;
  $('examBuilderLoading').outerHTML =
    `<div class="builder-settings">${field('etitle', 'Exam title', x.title)}${select('et', 'Track', tracks(), track)}${select('etype', 'Assessment category', [['lesson_exam','Lesson exam'],['quiz','Quiz'],['full_exam','Full exam']], x.assessment_type || (x.is_full_length ? 'full_exam' : 'lesson_exam'))}${field('emins','Duration in minutes', x.duration_seconds ? x.duration_seconds / 60 : 25,'number')}</div>
    <details class="builder-advanced"><summary>Review & scoring options</summary>${select('ereview','Review policy',[['full_review','Full answers after submission or window close'],['score_only','Score only'],['instructor_release','Release answers manually']],x.review_policy)}${area('emap','Exact raw-to-scaled conversion (optional JSON)',x.scoring_map ? JSON.stringify(x.scoring_map) : '')}</details>
    <section class="exam-picker" aria-label="Choose exam questions">
      <div class="builder-heading"><h3>Question bank</h3><strong id="eselected" role="status" aria-live="polite"></strong></div>
      <div class="builder-tabs">${button('ebrowse','Browse all questions')}${button('ereviewSelected','Selected questions')}</div>
      <div id="builderFilters"><div class="field"><label for="efilter">Find questions</label><input id="efilter" type="search" placeholder="Search question, lesson, or source code"></div>
      <div class="builder-filters">${select('etopic','Lesson',[['','All lessons']])}${select('edifficulty','Difficulty',[['','All levels'],['easy','Easy'],['medium','Medium'],['hard','Hard']])}${select('eqtype','Question type',[['','All types'],['mcq','Multiple choice'],['grid_in','Numeric answer']])}</div>${button('eclearFilters','Clear filters')}</div>
      <p id="eorderHint" class="hint" hidden>Use Move up or Move down to arrange your review order.${x.shuffle!==false?' Student question order is shuffled.':''}</p>
      <div class="builder-toolbar">${button('eaddPage','Add this page')}${select('epageSize','Per page',[['25','25'],['50','50'],['100','100']],'25')}<p id="eresults" class="hint" aria-live="polite"></p></div>
      <div class="builder-pagination"><button type="button" class="btn-sm" data-page-step="-1">Previous</button><label for="epage">Page <input id="epage" type="number" min="1" value="1"></label><span id="epages"></span><button type="button" class="btn-sm" data-page-step="1">Next</button></div>
      <div id="eqs" class="builder-questions"></div>
      <div class="builder-pagination"><button type="button" class="btn-sm" data-page-step="-1">Previous</button><span id="epageBottom"></span><button type="button" class="btn-sm" data-page-step="1">Next</button></div>
    </section>`;
  $('editSave').disabled = false;
  $('etitle').required = true; $('emins').min = '1'; $('emins').max = '240'; $('emins').step = 'any';
  if (x.id) $('et').disabled = true;
  function topics() {
    const names = [...new Set(questions.filter(q => q.track_id === model.track).map(q => q.topic).filter(Boolean))].sort((a,b) => a.localeCompare(b));
    $('etopic').innerHTML = '<option value="">All lessons</option>' + names.map(t => `<option value="${esc(t)}">${esc(t)}</option>`).join('');
  }
  function paint() {
    const {total,pages,start,rows} = model.pageData();
    $('eselected').textContent = `${model.selected.size} / 200 selected`;
    $('ereviewSelected').textContent = `Selected questions (${model.selected.size})`;
    $('ebrowse').setAttribute('aria-pressed', String(!model.selectedOnly));
    $('ereviewSelected').setAttribute('aria-pressed', String(model.selectedOnly));
    $('builderFilters').hidden = model.selectedOnly; $('eorderHint').hidden = !model.selectedOnly;
    $('eaddPage').hidden = model.selectedOnly;
    const addCount = Math.min(200-model.selected.size,rows.filter(q => !model.selected.has(q.id) && !q.assets?.release_hold_reason).length);
    $('eaddPage').disabled = addCount <= 0;
    $('eaddPage').textContent = `Add this page (${Math.max(0,addCount)})`;
    $('eresults').textContent = total ? `${start+1}–${Math.min(start+model.pageSize,total)} of ${total} questions` : 'No questions found';
    $('epage').value = model.page+1; $('epage').max = pages;
    $('epages').textContent = `of ${pages}`; $('epageBottom').textContent = `Page ${model.page+1} of ${pages}`;
    editor.querySelectorAll('[data-page-step]').forEach(b => b.disabled = Number(b.dataset.pageStep) < 0 ? model.page === 0 : model.page === pages-1);
    const selectedIds = [...model.selected];
    $('eqs').innerHTML = rows.length ? rows.map(q => {
      const checked = model.selected.has(q.id), index = selectedIds.indexOf(q.id), held = !!q.assets?.release_hold_reason;
      return `<article class="builder-question ${checked?'is-selected':''}"><div class="builder-question-top"><label class="builder-check"><input type="checkbox" data-qid="${esc(q.id)}" ${checked?'checked':''} ${!checked&&(held||model.selected.size>=200)?'disabled':''}><span>${checked ? `Selected · #${index+1}` : held ? questionHoldLabel(q) : model.selected.size>=200 ? '200-question limit reached' : 'Add question'}</span></label><span class="hint">${esc(q.difficulty || 'Medium')} · ${q.type==='mcq'?'Multiple choice':'Numeric answer'}</span></div>
        <p class="builder-topic">${esc(q.topic || 'Uncategorized')}</p><div class="builder-excerpt">${esc(q.stem)}</div>
        <details data-preview="${esc(q.id)}" ${expanded.has(q.id)?'open data-loaded="true"':''}><summary>Preview full question & figures</summary><div class="builder-preview-slot">${expanded.has(q.id)?examQuestionPreview(q):''}</div></details>
        ${model.selectedOnly ? `<div class="builder-order"><button type="button" class="btn-sm" data-move="${esc(q.id)}" data-delta="-1" ${index===0?'disabled':''} aria-label="Move question ${index+1} up">Move up</button><button type="button" class="btn-sm" data-move="${esc(q.id)}" data-delta="1" ${index===selectedIds.length-1?'disabled':''} aria-label="Move question ${index+1} down">Move down</button></div>` : ''}</article>`;
    }).join('') : `<div class="empty">${model.selectedOnly ? 'No questions selected yet. Choose Browse all questions to begin.' : 'No questions match these filters. Try another lesson or clear the filters.'}</div>`;
    // Render complete equations before CSS limits the visible excerpt. Slicing
    // the source can leave an unmatched delimiter or half of a fraction.
    $('eqs').querySelectorAll('.builder-excerpt').forEach(renderQuestionMath);
    $('eqs').querySelectorAll('[data-qid]').forEach(input => input.onchange = () => {
      const id = input.dataset.qid; model.toggle(id,input.checked); paint();
      $('eqs').querySelector(`[data-qid="${id}"]`)?.focus({preventScroll:true});
    });
    $('eqs').querySelectorAll('[data-preview]').forEach(details => {
      if(details.open) renderQuestionMath(details.querySelector('.builder-preview-slot'));
      details.ontoggle = () => {
      if(!details.isConnected)return;
      details.open ? expanded.add(details.dataset.preview) : expanded.delete(details.dataset.preview);
      if (!details.open || details.dataset.loaded) return;
      const slot = details.querySelector('.builder-preview-slot');
      slot.innerHTML = examQuestionPreview(model.byId.get(details.dataset.preview));
      details.dataset.loaded = 'true'; renderQuestionMath(slot);
    };});
    $('eqs').querySelectorAll('[data-move]').forEach(b => b.onclick = () => {model.move(b.dataset.move,Number(b.dataset.delta));paint();});
  }
  function navigate(step) { model.page += step; paint(); $('eqs').scrollIntoView({block:'start'}); }
  editor.querySelectorAll('[data-page-step]').forEach(b => b.onclick = () => navigate(Number(b.dataset.pageStep)));
  $('epage').onchange = () => {model.page = Math.max(0,(Number.parseInt(val('epage'),10)||1)-1);paint();};
  // Enter in a browsing control must never accidentally save the exam.
  editor.querySelector('.exam-picker').addEventListener('keydown', e => {if(e.key==='Enter'&&e.target.tagName==='INPUT'){e.preventDefault();e.target.dispatchEvent(new Event('change'));}});
  $('epageSize').onchange = () => {model.pageSize=Number(val('epageSize'));model.page=0;paint();};
  for (const [id,key] of [['efilter','search'],['etopic','topic'],['edifficulty','difficulty'],['eqtype','type']]) {
    $(id)[id==='efilter'?'oninput':'onchange'] = () => {model[key]=val(id);model.page=0;paint();};
  }
  $('eclearFilters').onclick = () => {for(const [id,key] of [['efilter','search'],['etopic','topic'],['edifficulty','difficulty'],['eqtype','type']]){$(id).value='';model[key]='';}model.page=0;paint();};
  $('ebrowse').onclick = () => {model.selectedOnly=false;model.page=0;paint();};
  $('ereviewSelected').onclick = () => {model.selectedOnly=true;model.page=0;paint();};
  $('eaddPage').onclick = () => {model.pageData().rows.forEach(q=>model.toggle(q.id,true));paint();};
  $('et').onchange = async () => {
    const nextTrack = val('et');
    if (nextTrack === model.track && questions.length) return;
    if(model.selected.size&&!confirm('Changing track will clear the selected questions. Continue?')){$('et').value=model.track;return;}
    const request = ++trackLoad;
    model = examPickerModel([], [], nextTrack);
    questions = [];
    expanded.clear();
    $('editSave').disabled = true;
    $('eresults').textContent = 'Loading questions for this track…';
    $('eqs').innerHTML = '<div class="empty" role="status">Loading questions for this track…</div>';
    try {
      const rows = await getRows('questions', false, '*', 'id', 'track_id', nextTrack);
      if (editor.open === false || request !== trackLoad) return;
      questions = rows;
      model = examPickerModel(questions, [], nextTrack);
      topics(); paint();
    } catch (e) {
      if (editor.open === false || request !== trackLoad) return;
      $('eresults').textContent = 'Could not load questions for this track.';
      $('eqs').innerHTML = `<div class="empty" role="alert">${esc(e.message || 'Could not load questions for this track.')}</div>`;
    } finally {
      if (editor.open !== false && request === trackLoad) $('editSave').disabled = false;
    }
  };
  topics();paint();
}
