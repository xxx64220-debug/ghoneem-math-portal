const {readFileSync}=require('node:fs');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');

// These are actual daily_state/daily_submit results from the rollback-only SQL
// test, not hand-written approximations of the RPC response. Fail if CI forgets
// the database step instead of silently skipping all of this coverage.
assert.ok(process.env.DAILY_QUIZ_TEST_PAYLOAD,'Run tests/daily_quiz_quality.sql first; see CI.md');
const data=JSON.parse(readFileSync(process.env.DAILY_QUIZ_TEST_PAYLOAD,'utf8'));
assert.deepEqual(data.tracks,['est','est2','sat']);
assert.equal(data.cases.length,36,'three tracks × three modes × two cohorts × before/after');
const templates=new Map(data.templates.map(q=>[q.id,q]));
assert.equal(templates.size,21);

const html=readFileSync('web/index.html','utf8');
const start=html.indexOf('function figure(a)');
const end=html.indexOf('const fmt =',start);
assert.ok(start>=0&&end>start,'production figure renderer must exist');
const renderer=html.slice(start,end);
const daily=readFileSync('web/daily-challenge.js','utf8');
const esc=s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;');

for(const track of data.tracks){
  test(`${track}: repaired answers agree with independent arithmetic`,()=>{
    const rows=data.templates.filter(q=>q.track_id===track);
    assert.deepEqual(rows.map(q=>q.kind),['angle','angle','length','length','polynomial','polynomial','table']);
    for(const q of rows){
      const chosen=q.choices.filter(c=>c.key===q.correct);
      assert.equal(chosen.length,1);
      const expected={angle:(Math.asin(1.6/4)*180/Math.PI).toFixed(1)+'°',
        length:String(4*4/1.6)+' cm',polynomial:String(-(2**2+2*2)),table:String(3+4)}[q.kind];
      assert.equal(chosen[0].text.replaceAll('−','-'),expected,`${track}/${q.kind}`);
    }
  });
}

for(const row of data.cases){
  test(`${row.track}/${row.mode}/cohort ${row.cohort}/${row.phase}: daily question rendering`,()=>{
    const sanitized=[];
    const c={esc,console,Date,setInterval(){},document:{addEventListener(){}},
      ST:{track:{id:row.track}},DASH:{daily:row.payload},
      // The existing VM tests do not provide a browser DOM. This spy covers
      // routing of trusted fixture SVG/table markup through the real figure()
      // function; DOM sanitization itself is outside this rendering test.
      cleanMarkup(markup){sanitized.push(markup);return markup;},ent:s=>s};
    vm.createContext(c);
    vm.runInContext(renderer,c);
    vm.runInContext(daily,c);
    const output=c.dailyPanel();
    const fields=[...output.matchAll(/<fieldset class="daily-question">([\s\S]*?)<\/fieldset>/g)].map(m=>m[1]);
    assert.equal(fields.length,5);
    assert.doesNotMatch(output,/in the original question/i);
    row.payload.quiz.forEach((q,i)=>{
      const expected=templates.get(q.id);
      assert.ok(expected,`unknown generated question ${q.id}`);
      assert.equal(expected.track_id,row.track);
      assert.ok(fields[i].includes(esc(expected.stem)),'complete context must stay with its question');
      assert.deepEqual(q.assets,expected.assets);
      assert.equal(q.assets.release_hold_reason,undefined);
      assert.equal((fields[i].match(/type="radio"/g)||[]).length,expected.choices.length);
      for(const choice of expected.choices){
        assert.ok(choice.text.trim());
        assert.ok(fields[i].includes(`name="daily-${q.id}" value="${esc(choice.key)}"`));
        assert.ok(fields[i].includes(`<b>${esc(choice.key)}.</b> ${esc(choice.text)}`));
      }
      for(const asset of ['svg','html']){
        if(expected.assets[asset]){
          assert.ok(fields[i].includes(expected.assets[asset]),`${asset} missing or attached to another question`);
          assert.ok(sanitized.includes(expected.assets[asset]),`${asset} bypassed figure sanitizer`);
        }
      }
      assert.equal(fields[i].includes('<svg'),['angle','length'].includes(expected.kind));
      if(row.phase==='before'){
        assert.equal(q.answer,null);
        assert.doesNotMatch(fields[i],/daily-solution|Correct answer:/);
        assert.ok(!fields[i].includes(esc(expected.explanation)),'explanation leaked before submission');
      }else{
        assert.equal(q.answer.correct,expected.correct);
        assert.equal(q.answer.submitted,expected.correct);
        assert.equal(q.answer.explanation,expected.explanation);
        assert.ok(fields[i].includes(esc(expected.explanation)),'explanation missing from completed review');
        assert.match(fields[i],/daily-solution right/);
        assert.equal((fields[i].match(/checked disabled/g)||[]).length,1,'correct submitted radio must remain selected');
      }
    });
  });
}
