const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('./passage-runtime/node_modules/jsdom');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function app(enabled=true, stalledAuth=false){
 const html=fs.readFileSync('web/practice-bundles.html','utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/g,'');
 const dom=new JSDOM(html,{url:'https://fixture.invalid/practice-bundles.html',runScripts:'outside-only'}),w=dom.window;w.document.documentElement.dataset.practiceBundlesEnabled=String(enabled);w.confirm=()=>true;w.PortalMath={render(){}};
 for(const f of ['tests/fixtures/bundle-browser-fixture.js','web/bundle-core.js','web/bundle-figures.js'])w.eval(fs.readFileSync(f,'utf8'));
 if(stalledAuth){const createClient=w.supabase.createClient;w.supabase.createClient=(...args)=>{const client=createClient(...args);client.auth.getUser=()=>new Promise(()=>{});return client;};const realTimeout=w.setTimeout.bind(w);w.setTimeout=(fn,ms,...args)=>realTimeout(fn,ms===20000?5:ms,...args);}
 w.eval(fs.readFileSync('web/practice-bundles.js','utf8'));
 await sleep(15);return {dom,w,$:id=>w.document.getElementById(id),fixture:w.BundleFixture};
}
async function create(a){a.$('count').value='2';a.$('builderForm').dispatchEvent(new a.w.Event('submit',{cancelable:true}));await sleep(10);}
function answer(a,value){const input=a.$('question').querySelector(`[name=answer]${value.length===1&&isNaN(value)?'[value="'+value+'"]':''}`);input.value=value;input.checked=true;input.dispatchEvent(new a.w.Event(input.type==='radio'?'change':'input',{bubbles:true}));}
test('UI builds, pauses, resumes, submits, reviews and retakes without changing the prior attempt',async()=>{
 const a=await app();try{assert.equal(a.$('course').options.length,6);assert.match(a.$('availability').textContent,/24/);await create(a);assert(a.$('question').querySelector('svg'));assert.equal(a.$('submit').disabled,true);
 answer(a,'C');a.$('pause').click();await sleep(20);assert.match(a.$('historyList').textContent,/1\/2 answered/);assert.equal(a.fixture.bundles[0].completed_at,null);
 a.$('historyList').querySelector('button').click();await sleep(20);assert(a.$('question').querySelector('[value=C]').checked);a.$('next').click();assert(a.$('question').querySelector('table'));answer(a,'7');assert.equal(a.$('submit').disabled,false);a.$('submit').click();await sleep(20);assert.match(a.$('progress').textContent,/2\/2 correct/);assert.match(a.$('question').textContent,/Accepted answer: 7/);
 a.$('retake').click();await sleep(20);assert.equal(a.fixture.bundles.length,2);assert.equal(Object.keys(a.fixture.bundles[0].answers).length,0);assert.equal(a.fixture.bundles[1].score,2);assert.equal(a.$('question').querySelector('.bundle-result'),null);assert.equal(a.$('question').querySelector('input').disabled,false);
 }finally{a.dom.window.close();}
});
test('failed save retains a local draft and retry saves it before leaving',async()=>{const a=await app();try{await create(a);answer(a,'C');a.fixture.failNextSave=true;a.$('pause').click();await sleep(20);assert.equal(a.$('runner').hidden,false);assert.match(a.$('saveStatus').textContent,/local answers/);assert(a.w.localStorage.length>0);a.$('pause').click();await sleep(20);assert.equal(a.$('runner').hidden,true);assert.equal(a.fixture.bundles[0].answers[a.fixture.bundles[0].question_ids[0]],'C');}finally{a.dom.window.close();}});
test('conflicting save stops editing and keeps local answers for comparison',async()=>{const a=await app();try{await create(a);answer(a,'B');a.fixture.conflictNextSave=true;a.$('pause').click();await sleep(20);assert.equal(a.$('conflict').hidden,false);assert.match(a.$('localAnswers').textContent,/'B'|"B"/);assert.equal(a.$('submit').disabled,true);assert.equal(a.$('question').querySelector('input').disabled,true);}finally{a.dom.window.close();}});
test('submission in flight cannot navigate away or create a second bundle',async()=>{const a=await app();try{await create(a);answer(a,'C');a.$('next').click();answer(a,'7');a.fixture.delaySave=40;a.$('submit').click();a.$('builderTab').click();assert.equal(a.$('runner').hidden,false);assert.equal(a.$('builder').hidden,true);await sleep(70);assert.match(a.$('progress').textContent,/2\/2 correct/);}finally{a.dom.window.close();}});

test('unreleased feature makes no protected API requests and exposes no practice workspace',async()=>{const a=await app(false);try{assert.equal(a.fixture.requests.length,0);assert.equal(a.$('workspace').hidden,true);assert.match(a.$('message').textContent,/being prepared/);}finally{a.dom.window.close();}});

test('stalled sign-in shows a retry message without exposing the workspace or creating practice',async()=>{const a=await app(true,true);try{assert.match(a.$('message').textContent,/connection timed out/);assert.equal(a.$('retry').hidden,false);assert.equal(a.$('workspace').hidden,true);assert.equal(a.fixture.requests.length,0);}finally{a.dom.window.close();}});

test('review renders encoded units as text without accepting HTML from explanations',async()=>{const a=await app();try{await create(a);answer(a,'C');a.$('next').click();answer(a,'7');a.$('submit').click();await sleep(20);a.$('pause').click();await sleep(20);a.fixture.bundles[0].questions[1].explanation='Area = 9 m&sup2;, volume = 27 m&sup3;. &lt;img src=x onerror=alert(1)&gt;';a.$('historyList').querySelector('button').click();await sleep(20);assert.match(a.$('question').textContent,/9 m², volume = 27 m³/);assert.equal(a.$('question').querySelector('.explanation img'),null);assert.match(a.$('question').querySelector('.explanation').textContent,/<img src=x/);}finally{a.dom.window.close();}});

test('changing courses preserves the selected track in the reload URL and API request',async()=>{const a=await app();try{a.$('course').value='est2';a.$('course').dispatchEvent(new a.w.Event('change'));await sleep(20);assert.equal(a.w.location.search,'?track=est2');assert.equal(a.fixture.requests.at(-1).track,'est2');assert.equal(a.$('course').value,'est2');}finally{a.dom.window.close();}});

test('SAT has four domains with nested subtopics, accurate counts and explicit shortage handling',async()=>{
 const a=await app();try{
  assert.deepEqual([...a.$('section').options].map(x=>x.textContent),['All four domains','Algebra','Advanced Math','Problem-Solving and Data Analysis','Geometry and Trigonometry']);
  a.$('section').value='Geometry and Trigonometry';a.$('section').dispatchEvent(new a.w.Event('change'));
  const sub=a.$('lessonOptions').querySelector('[data-subtopic][value="Right triangles"]');assert(sub);sub.checked=true;sub.dispatchEvent(new a.w.Event('change',{bubbles:true}));
  assert.match(a.$('availability').textContent,/8 eligible/);assert.equal(a.$('create').disabled,true);assert.equal(a.$('useAvailable').hidden,false);
  a.$('useAvailable').click();assert.equal(a.$('count').value,'8');assert.equal(a.$('create').disabled,false);
  a.$('exclude').checked=false;a.$('exclude').dispatchEvent(new a.w.Event('input'));assert.match(a.$('availability').textContent,/12 eligible/);
  const lesson=sub.closest('.bundle-lesson').querySelector('[data-lesson]');lesson.checked=true;lesson.dispatchEvent(new a.w.Event('change',{bubbles:true}));assert.equal(sub.checked,false);assert.match(a.$('availability').textContent,/22 eligible/);
  sub.checked=true;sub.dispatchEvent(new a.w.Event('change',{bubbles:true}));assert.equal(lesson.checked,false);
  a.$('builderForm').dispatchEvent(new a.w.Event('submit',{cancelable:true}));await sleep(20);
  const sent=a.fixture.requests.find(r=>r.action==='create').settings;assert.deepEqual(JSON.parse(JSON.stringify(sent.topics)),[]);assert.deepEqual(JSON.parse(JSON.stringify(sent.subtopics)),[{topic:'Triangles and similarity',subtopic:'Right triangles'}]);assert.equal(sent.exclude_answered,false);
 }finally{a.dom.window.close();}
});
test('failed course catalogue cannot reuse old course counts or enable creation',async()=>{
 const a=await app();try{a.fixture.failCatalog=true;a.$('course').value='est';a.$('course').dispatchEvent(new a.w.Event('change'));await sleep(20);a.$('exclude').dispatchEvent(new a.w.Event('input'));assert.equal(a.$('create').disabled,true);assert.equal(a.$('lessonOptions').children.length,0);assert.match(a.$('availability').textContent,/Refresh/);a.$('builderForm').dispatchEvent(new a.w.Event('submit',{cancelable:true}));await sleep(10);assert.equal(a.fixture.requests.filter(r=>r.action==='create').length,0);}finally{a.dom.window.close();}
});
test('refreshing counts preserves a selected subtopic and keyboard focus controls',async()=>{
 const a=await app();try{const sub=a.$('lessonOptions').querySelector('[data-subtopic][value="Right triangles"]');sub.checked=true;sub.dispatchEvent(new a.w.Event('change',{bubbles:true}));a.$('refreshAvailability').click();await sleep(20);assert(a.$('lessonOptions').querySelector('[data-subtopic][value="Right triangles"]').checked);assert.match(a.$('availability').textContent,/8 eligible/);}finally{a.dom.window.close();}
});

for(const track of ['est','est2','act2','est_eng','sat_eng'])test(track+' supports nested subtopics, shortages and course-specific requests',async()=>{
 const a=await app();try{
  a.$('course').value=track;a.$('course').dispatchEvent(new a.w.Event('change'));await sleep(20);
  const english=track.endsWith('_eng'),topic=english?'SEC · Subject–verb agreement':'Triangles and similarity',subtopic=english?'Singular subjects':'Right triangles';
  assert.equal(a.$('section').options[0].textContent,'All main topics');
  assert(![...a.$('section').options].some(x=>x.textContent==='Geometry and Trigonometry'));
  assert.match(a.$('topicNote').textContent,/individual subtopics/);
  const sub=a.$('lessonOptions').querySelector('[data-subtopic][value="'+subtopic+'"]');assert(sub);sub.checked=true;sub.dispatchEvent(new a.w.Event('change',{bubbles:true}));
  assert.match(a.$('availability').textContent,/8 eligible/);assert.equal(a.$('create').disabled,true);
  a.$('useAvailable').click();assert.equal(a.$('count').value,'8');assert.equal(a.$('create').disabled,false);
  a.$('difficulty').value='hard';a.$('difficulty').dispatchEvent(new a.w.Event('input'));assert.match(a.$('availability').textContent,/0 eligible/);assert.equal(a.$('create').disabled,true);
  a.$('difficulty').value='medium';a.$('difficulty').dispatchEvent(new a.w.Event('input'));
  a.$('exclude').checked=false;a.$('exclude').dispatchEvent(new a.w.Event('input'));assert.match(a.$('availability').textContent,/12 eligible/);
  a.$('builderForm').dispatchEvent(new a.w.Event('submit',{cancelable:true}));await sleep(20);
  const request=a.fixture.requests.find(r=>r.action==='create');assert.equal(request.track,track);
  assert.deepEqual(JSON.parse(JSON.stringify(request.settings.subtopics)),[{topic,subtopic}]);
 }finally{a.dom.window.close();}
});
