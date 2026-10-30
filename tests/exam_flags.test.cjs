const PORTAL_STATIC=require('./public-artifact-dir.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const html=fs.readFileSync('web/index.html','utf8');
function setup(){
 const dom=new JSDOM(html,{runScripts:'outside-only',url:'https://portal.invalid'}),w=dom.window;
 const ctx=dom.getInternalVMContext();w.eval=code=>vm.runInContext(code,ctx);
 w.scrollTo=()=>{};w.reportButton=()=>'';w.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:null}}),getUser:async()=>({data:{user:null}})}})};
 try{
  w.eval(html.split('<script>')[1].split('</script>')[0]);
  w.eval("ST.track={id:'sat'};ST.run={exam:{track_id:'sat'},attempt:{id:'fixture'},questions:[{id:'q1',topic:'Linear functions and slope',stem:'Solve 2x = 8.',type:'mcq',choices:[{key:'A',text:'4'},{key:'B',text:'8'}],response:'A'},{id:'q2',topic:'Circles',stem:'A circle has radius 3. What is its diameter?',type:'grid_in',response:''}]};ST.idx=0;renderQ();renderPalette();");
 }catch(e){dom.window.close();throw e;}
 return {dom,w,d:w.document};
}
test('active flag has a filled state, accessible pressed state, question badge and palette marker',()=>{
 const f=setup();try{
  const button=f.d.getElementById('flagBtn');assert.equal(button.getAttribute('aria-pressed'),'false');button.click();
  assert.equal(button.textContent,'⚑ Flagged');assert(button.classList.contains('is-flagged'));assert.equal(button.getAttribute('aria-pressed'),'true');
  assert.equal(f.d.querySelector('.flag-notice').textContent,'⚑ Flagged for review');
  const pal=f.d.querySelector('.pal');assert(pal.classList.contains('flagged'));assert(pal.classList.contains('answered'));assert(pal.classList.contains('current'));assert.match(pal.getAttribute('aria-label'),/answered, flagged for review/);assert.match(f.d.getElementById('progress').textContent,/1 flagged/);
  f.w.eval('ST.idx=1;renderQ();renderPalette()');assert.equal(button.getAttribute('aria-pressed'),'false');assert.equal(f.d.querySelector('.flag-notice'),null);
  f.w.eval('ST.idx=0;renderQ();renderPalette()');assert.equal(button.getAttribute('aria-pressed'),'true');button.click();assert.equal(button.getAttribute('aria-pressed'),'false');assert(!button.classList.contains('is-flagged'));assert.equal(f.d.querySelector('.flag-notice'),null);assert.equal(f.d.querySelector('.pal.flagged'),null);
 }finally{f.dom.window.close();}
});
test('uploaded source paper cards show original module sizes rather than 22 each',()=>{
 const f=setup();try{
  f.w.eval("DASH.exams=[24,27].map((n,i)=>({id:'m'+i,title:'SAT Trial 2026 October — Paper 1 · Hard route — Module '+(i+1),assessment_type:'full_exam',exam_set_code:'source-hard',module_number:i+1,questions:n,duration_seconds:2100,open:true,last:{id:'a'+i,status:'graded',score:n,total:n}}));document.getElementById('examList').innerHTML=fullExamSection();");
  const text=f.d.querySelector('.exam-pair').textContent;assert.match(text,/24 \+ 27 questions/);assert.match(text,/51\/51/);assert(!text.includes('22 questions each'));assert.match(text,/Review full exam/);
 }finally{f.dom.window.close();}
});
test('public build matches source and active flag is distinct for answered questions',()=>{
 assert.equal(fs.readFileSync((PORTAL_STATIC + '/index.html'),'utf8'),html);assert.match(html,/#flagBtn\.is-flagged\{background:#ffe29a/);assert.match(html,/\.pal\.flagged\.answered\{/);assert.match(html,/content:"⚑"/);
});
