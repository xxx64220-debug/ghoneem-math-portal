const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('./passage-runtime/node_modules/jsdom');
const source=fs.readFileSync('web/portal-controls.js','utf8');
function app(track='sat',query=''){
 const dom=new JSDOM('<html data-practice-bundles-enabled="true"><body><div id="dashboardContent"></div></body></html>',{url:'https://fixture.invalid/'+query,runScripts:'outside-only'}),w=dom.window;
 w.ST={track:{id:track},tracks:[{id:track}]};w.DASH={access:{practice_open:true},mistakes:{items:[{topic:'Old legacy topic',assets:{curriculum_lesson:'Triangles & similarity'}}]}};
 w.esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));w.lessonCard=l=>'<article>'+w.esc(l.lesson)+'</article>';w.focusSection=()=>'<p>Based on your latest reviewed result for each question.</p>';w.mistakesPanel=()=>'<article class="mistake-card"><button data-notebook-submit="q">Check answer</button></article>';
 let opened=[],views=[],delegated=0;w.openTrack=async t=>{opened.push(t.id);w.ST.track=t;};w.setDashboardView=v=>views.push(v);w.openStudyLink=async()=>{delegated++;return 'original';};
 w.eval(source.slice(source.indexOf('// Shared entry points')));
 return {dom,w,opened,views,get delegated(){return delegated;}};
}
for(const track of ['sat','est','est2','act2','est_eng','sat_eng'])test('lesson and notebook links preserve course and canonical lesson: '+track,()=>{
 const a=app(track);try{
  for(const html of [a.w.lessonCard({lesson:'Triangles & similarity',exam_seen:3,bundle_seen:2}),a.w.mistakesPanel()]){
   const box=a.w.document.createElement('div');box.innerHTML=html;const url=new URL(box.querySelector('a').href);
   assert.equal(url.pathname,'/practice-bundles.html');assert.equal(url.searchParams.get('track'),track);assert.equal(url.searchParams.get('lesson'),'Triangles & similarity');
  }
  assert.match(a.w.mistakesPanel(),/data-notebook-submit="q"/,'existing correction control preserved');
  assert.match(a.w.lessonCard({lesson:'X',exam_seen:3,bundle_seen:2}),/3 exam · 2 bundle/);
  a.w.DASH.access.practice_open=false;assert.equal(a.w.portalBundleLessonLink('X'),'','historical-only enrollment cannot start practice');
 }finally{a.dom.window.close();}
});
for(const track of ['sat','est','est2','act2','est_eng','sat_eng'])for(const view of ['focus','mistakes','finalsDiagnosis'])test('return link selects existing view without creating assessment: '+track+'/'+view,async()=>{
 const a=app(track,'?'+new URLSearchParams({practice_track:track,practice_view:view}));try{assert.equal(await a.w.openStudyLink(),true);assert.deepEqual(a.opened,[track]);assert.deepEqual(a.views,[view]);assert.equal(a.delegated,0);}finally{a.dom.window.close();}
});
test('Today links and unavailable courses retain the existing access path',async()=>{
 for(const query of ['?study_track=sat&study_activity=practice&study_exam=assigned','?practice_track=other&practice_view=mistakes','?practice_track=sat&practice_view=unsafe']){
  const a=app('sat',query);try{assert.equal(await a.w.openStudyLink(),'original');assert.deepEqual(a.opened,[]);assert.equal(a.delegated,1);}finally{a.dom.window.close();}
 }
});
