const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const {test}=require('node:test');
function setup(admin=false){
 const nodes=new Map(),listeners={};
 const node=id=>{if(!nodes.has(id))nodes.set(id,{id,value:'',innerHTML:'',textContent:'',disabled:false,hidden:false,dataset:{},style:{},classList:{toggle(){},add(){},remove(){}},addEventListener(name,fn){this[name]=fn},setAttribute(){},querySelectorAll(){return[]},showModal(){this.open=true},close(){this.open=false},focus(){}});return nodes.get(id)};
 const ctx={console,Set,Map,Date,Intl,crypto:require('node:crypto').webcrypto,ST:{track:admin?'est2':{id:'est2'},view:'revisionAdmin',tracks:[{id:'est2',name:'EST II'}],me:{role:'admin'}},DASH:{view:'revision'},document:{getElementById:node,querySelectorAll(){return[]},addEventListener(name,fn){listeners[name]=fn}},$:node,esc:s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])),friendly:s=>s,select:()=>'',field:()=>'',area:()=>'',wrapTable:s=>s,val:id=>node(id).value,render(){},calls:[],async fn(name,options){ctx.calls.push({name,options});return {ok:true,json:ctx.response||{}}}};
 vm.createContext(ctx);vm.runInContext(fs.readFileSync(admin?'web/admin-controls.js':'web/portal-controls.js','utf8'),ctx);return ctx;
}
test('question reports attach the track and question, preserve request IDs on retry, and escape labels',async()=>{
 const c=setup();assert.match(c.reportButton('x"<','revision'),/x&quot;&lt;/);
 c.openPortalReport('question-id','Final revision');c.$('portalReportMessage').value='The diagram seems incomplete.';
 c.response={error:'temporary failure'};c.fn=async(name,options)=>{c.calls.push({name,options});return {ok:c.calls.length>1,json:{}}};
 await c.$('portalReportForm').onsubmit({preventDefault(){}});await c.$('portalReportForm').onsubmit({preventDefault(){}});
 const first=c.calls[0].options.body.data,second=c.calls[1].options.body.data;
 assert.equal(first.question_id,'question-id');assert.equal(first.track,'est2');assert.equal(first.kind,'question');assert.equal(first.request_id,second.request_id);assert.equal(c.$('portalReportSend').hidden,true);
});
test('revision management escapes content and sends explicit release/visibility settings',async()=>{
 const c=setup(true);c.response={visible:true,items:[{id:'q1',lesson:'<lesson>',idea:'Idea',source:'Paper',stem:'<script>bad</script>',difficulty:'easy',active:true,ready:true}]};
 await c.revisionAdmin();assert.match(c.$('revisionAdminTable').innerHTML,/&lt;script&gt;/);assert.doesNotMatch(c.$('revisionAdminTable').innerHTML,/<script>/);
 c.$('revisionSelectShown').onclick();c.response={count:1};await c.$('revisionHide').onclick();
 assert.equal(c.calls.at(-1).options.body.action,'revision.release');assert.equal(c.calls.at(-1).options.body.data.active,false);assert.deepEqual([...c.calls.at(-1).options.body.data.ids],['q1']);
});
test('stale admin reads cannot overwrite the new track',async()=>{
 const c=setup(true);let resolve;c.fn=()=>new Promise(r=>resolve=r);const pending=c.revisionAdmin();c.ST.track='est';c.$('view').innerHTML='New track';resolve({ok:true,json:{visible:true,items:[]}});await pending;assert.equal(c.$('view').innerHTML,'New track');
});
test('quiz controls retain selected questions and hide reset actions from instructors',async()=>{
 const c=setup(true);c.ST.view='quizAdmin';c.ST.me.role='instructor';c.response={settings:{daily_mode:'selected',daily_question_ids:['q1']},today_frozen:true,questions:[{id:'q1',lesson:'Algebra',stem:'Solve',source:'Paper'}],students:[{id:'s1',name:'Student',completed:2,points:90}]};
 await c.quizAdmin();assert.match(c.$('view').innerHTML,/Today’s questions have already been opened/);assert.doesNotMatch(c.$('view').innerHTML,/data-quiz-reset/);assert.match(c.$('quizQuestionList').innerHTML,/data-quiz-pick="q1" checked/);
 c.$('quizMode').value='selected';c.response={eligible:5,today_frozen:true};await c.$('quizSave').onclick();assert.equal(c.calls.at(-1).options.body.action,'quiz.save');assert.deepEqual([...c.calls.at(-1).options.body.data.ids],['q1']);
});
test('EST II revision omits the source chooser and filters out other programmes',()=>{
 const c=setup();Object.assign(c,{setDashboardView(){},window:{},friendly:x=>x});vm.runInContext(fs.readFileSync('web/final-revision.js','utf8'),c);
 vm.runInContext("REV.data={items:[{id:'q1',source:'est2',lesson:'Vectors',idea:'Dot product',difficulty:'hard',programmes:['est2'],focus:{collections:[]}},{id:'q2',source:'sat',lesson:'Algebra',idea:'Linear',difficulty:'easy',programmes:['sat'],focus:{collections:[]}}]};REV.collection='all';REV.level='mixed';",c);
 assert.equal(vm.runInContext('revisionRows().length',c),1);assert.equal(vm.runInContext('revisionRows()[0].source',c),'est2');
});
