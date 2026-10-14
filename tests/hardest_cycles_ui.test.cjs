const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const html=fs.readFileSync('web/admin.html','utf8');
const code=html.slice(html.indexOf('async function questions('),html.indexOf('\nasync function exams(){'));
function setup(role='admin',track='sat'){
 const dom=new JSDOM('<div id="view"></div>'),calls=[],exports=[];let save;
 const cycles=[{id:'old',track_id:'sat',title:'October trial',starts_at:'2026-09-01',ends_at:'2026-10-09'},{id:'open',track_id:'sat',title:'Next trial',starts_at:'2026-10-09',ends_at:null}];
 const c={document:dom.window.document,ST:{view:'questions',me:{id:'staff',role},track},hardestCycle:'current',hardestRequest:0,
 $:id=>dom.window.document.getElementById(id),esc:x=>String(x??''),wrapTable:x=>x,bar:()=>'',
 sb:{from(){return {select(){return this;},order(){return Promise.resolve({data:cycles});}}},rpc:async(name,args)=>{calls.push({rpc:name,args});return {data:{}};}},
 hardestReport:{cancel(){},clear(){calls.push({clear:true});},page:async scope=>{calls.push({scope});return {rows:[{rank:1,track_id:'sat',lesson:'Circles',question_id:'q',stem:'Question',sources:'Full exam',answered_by:10,got_it_right:2,got_it_wrong:8,percent_correct:20}],hasMore:false};},pageSize:50,all:async scope=>{calls.push({exportScope:scope});return []; }},
 csv:(rows,name)=>exports.push({rows,name}),questionPdf(){},alert(){},window:{},
 field:()=>'<input id="title">',val:()=>'October finished',dialog:(title,body,onSave)=>save=onSave};
 vm.createContext(c);vm.runInContext(code,c);return {c,calls,exports,dom,get save(){return save;}};
}
test('cycle selection scopes queries and exports; archive sends expected cycle ID',async()=>{
 const s=setup();await vm.runInContext('questions()',s.c);
 assert.equal(s.c.$('hardCycle').value,'current');assert.match(s.c.$('hardCycle').innerHTML,/October trial/);
 s.c.$('hardCycle').value='old';s.c.$('hardCycle').onchange();await new Promise(r=>setImmediate(r));
 assert.equal(s.calls.at(-1).scope.cycle,'old');assert.match(s.c.$('hardCycleNote').textContent,/Archived: October trial/);
 await s.c.$('csvBtn').onclick();assert.equal(s.calls.find(x=>x.exportScope).exportScope.cycle,'old');
 s.c.$('hardArchive').onclick();await s.save();
 assert.deepEqual(JSON.parse(JSON.stringify(s.calls.find(x=>x.rpc))),{rpc:'staff_archive_hardest_cycle',args:{p_track:'sat',p_title:'October finished',p_expected_cycle:'open'}});
 assert.equal(s.c.hardestCycle,'current');assert(s.calls.some(x=>x.clear));s.dom.window.close();
});
test('instructors cannot close cycles and all-track view requires one track to archive',async()=>{
 const a=setup('instructor');await vm.runInContext('questions()',a.c);assert.equal(a.c.$('hardArchive'),null);assert.doesNotMatch(a.c.$('hardCycle').innerHTML,/October trial/);a.dom.window.close();
 const b=setup('admin','');await vm.runInContext('questions()',b.c);assert.equal(b.c.$('hardArchive').disabled,true);b.dom.window.close();
});
