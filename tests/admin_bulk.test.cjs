const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const read=f=>fs.readFileSync('web/'+f,'utf8');
const tick=()=>new Promise(r=>setImmediate(r));
function setup(role='admin'){
 const dom=new JSDOM('<div id="tabs"></div><select id="adminSection"></select><select id="trackSel"></select><button id="outBtn"></button><div id="view"></div><dialog id="editor"></dialog>',{runScripts:'outside-only'}),w=dom.window,calls=[],alerts=[];
 w.$=id=>w.document.getElementById(id);w.esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
 w.ST={view:'exams',track:'sat',me:{id:'self',role},tracks:[{id:'sat',name:'SAT'},{id:'est',name:'EST I'},{id:'est2',name:'EST II'},{id:'est_eng',name:'English'}]};w.alert=x=>alerts.push(x);
 w.eval(read('admin.html').slice(read('admin.html').indexOf('const field='),read('admin.html').indexOf('function dialog(')).replace(/const (field|area|select|tracks|val|jval)=/g,'window.$1='));
 w.render=async()=>{};w.mutation=async(action,data)=>{calls.push({action,data});};w.sb={rpc:async(action,data)=>{calls.push({action,data});return {data:{}};}};w.getRows=async()=>[];
 w.$('editor').showModal=function(){this.open=true;};w.$('editor').close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
 w.eval(read('admin-bulk.js'));
 function mount(mode,rows){w.$('view').innerHTML='<div class="table-wrap"><table><thead><tr><th>Item</th></tr></thead><tbody>'+rows.map(()=>'<tr><td>Item</td></tr>').join('')+'</tbody></table></div>';w.AdminBulk.mount(mode,rows,w.$('view').querySelector('table'));}
 const query=s=>w.document.querySelector(s),choose=async action=>{query('[data-bulk-action]').value=action;query('[data-bulk-action]').dispatchEvent(new w.Event('change'));query('[data-bulk-apply]').click();await tick();};
 const pick=()=>query('[data-bulk-shown]').click();const submit=async()=>{w.$('bulkForm').dispatchEvent(new w.Event('submit',{cancelable:true}));await tick();};
 return {dom,w,calls,alerts,mount,query,choose,pick,submit};
}
const exam=(id,track='sat')=>({id,title:'Exam '+id,track_id:track});
test('select shown, mixed checkbox, hidden-page selection and navigation reset',async()=>{
 const s=setup();s.mount('exams',[exam('1'),exam('2')]);assert(s.query('[data-bulk-apply]').disabled);s.pick();assert(s.query('[data-bulk-all]').checked);
 s.query('[data-bulk-pick="1"]').click();assert(s.query('[data-bulk-all]').indeterminate);s.mount('exams',[exam('3')]);s.pick();assert.match(s.query('[data-bulk-count]').textContent,/2 selected/);
 s.query('[data-bulk-all]').click();assert.match(s.query('[data-bulk-count]').textContent,/1 selected · 0/);await s.choose('publish');assert.match(s.w.$('editor').textContent,/Exam 2/);await s.submit();assert.deepEqual(JSON.parse(JSON.stringify(s.calls)),[{action:'exam.save',data:{id:'2',is_published:true}}]);
 s.w.$('bulkCancel').click();await tick();s.w.ST.track='est';await s.w.render();s.mount('exams',[exam('3','est')]);assert.match(s.query('[data-bulk-count]').textContent,/0 selected/);s.dom.window.close();
});
test('accounts exclude administrators and self; status edits preserve names and roles',async()=>{
 const s=setup();s.w.ST.view='students';s.mount('accounts',[{user_id:'self',role:'admin'},{user_id:'a',role:'admin'},{user_id:'u',role:'student',full_name:'Student'},{user_id:'i',role:'instructor'}]);assert.equal(s.w.document.querySelectorAll('[data-bulk-pick]').length,2);s.pick();await s.choose('suspended');await s.submit();assert.equal(s.calls.length,2);assert(s.calls.every(x=>x.action==='user.update'&&x.data.status==='suspended'&&Object.keys(x.data).length===2));s.dom.window.close();
 const i=setup('instructor');i.mount('accounts',[{user_id:'u',role:'student'}]);assert.equal(i.query('[data-bulk-toolbar]'),null);i.dom.window.close();
});
test('student access action rejects mixed roles before any write and supports all portal tracks',async()=>{
 const s=setup();s.mount('accounts',[{user_id:'u',role:'student'},{user_id:'i',role:'instructor'}]);s.pick();await s.choose('enroll');assert.match(s.alerts[0],/student accounts only/);assert.equal(s.calls.length,0);s.dom.window.close();
 for(const track of ['sat','est','est2','est_eng']){const f=setup();f.mount('accounts',[{user_id:'u',role:'student'}]);f.pick();await f.choose('enroll');f.w.$('bulkTrack').value=track;await f.submit();assert.equal(f.calls[0].data.track_id,track);assert.equal(f.calls[0].data.status,'active');f.dom.window.close();}
});
test('bulk publish, unpublish, category and review use bounded existing staff actions',async()=>{
 for(const action of ['publish','unpublish','category','review']){const s=setup('instructor');s.mount('exams',[exam('1'),exam('2')]);s.pick();await s.choose(action);if(action==='category')s.w.$('bulkCategory').value='quiz';await s.submit();assert.equal(s.calls.length,2);assert(s.calls.every(x=>x.action===({publish:'exam.save',unpublish:'exam.save',category:'exam.classify',review:'review.release'})[action]));assert(s.query('[data-bulk-apply]').disabled);s.dom.window.close();}
});
test('assign keeps existing target assignments, validates dates and rejects mixed exam tracks',async()=>{
 const s=setup();s.w.getRows=async table=>({roster:[],groups:[{id:'g',track_id:'sat',name:'Group'}],assignments:[{exam_id:'1',group_id:'g'}]})[table];s.mount('exams',[exam('1'),exam('2')]);s.pick();await s.choose('assign');s.w.$('bulkOpen').value='2026-11-01T10:00';s.w.$('bulkClose').value='2026-10-31T10:00';await s.submit();assert.equal(s.calls.length,0);assert.match(s.w.$('bulkErrors').textContent,/after opening/);s.w.$('bulkClose').value='2026-11-02T10:00';await s.submit();assert.equal(s.calls.length,1);assert.equal(s.calls[0].data.exam_id,'2');assert.equal(s.calls[0].data.group_id,'g');assert.match(s.w.$('bulkProgress').textContent,/1 updated · 1 already assigned/);s.dom.window.close();
 const m=setup();m.mount('exams',[exam('1'),exam('2','est')]);m.pick();await m.choose('assign');assert.match(m.alerts[0],/one track/);assert.equal(m.calls.length,0);m.dom.window.close();
});
test('course edits preserve other fields and optimistic versions; partial retry never repeats successes',async()=>{
 const s=setup();const rows=['u1','u2'].map(user_id=>({user_id,track_id:'sat',full_name:user_id,status:'active',payment_status:'paid',starts_at:'2026-10-01T00:00:00Z',ends_at:'2026-12-01T00:00:00Z',course_label:'November',access_version:7}));let fail=true;
 s.w.sb.rpc=async(action,data)=>{s.calls.push({action,data});return data.p_user==='u2'&&fail?{error:{message:'access_changed_refresh'}}:{data:{}};};s.mount('access',rows);s.pick();await s.choose('paused');await s.submit();assert.equal(s.calls.length,2);assert.match(s.w.$('bulkErrors').textContent,/u2: access_changed_refresh/);assert.match(s.query('[data-bulk-count]').textContent,/1 selected/);assert.equal(s.calls[0].data.p_expected_version,7);assert.deepEqual(JSON.parse(JSON.stringify(s.calls[0].data.p_data)),{status:'paused',payment_status:'paid',course_label:'November',starts_at:rows[0].starts_at,ends_at:rows[0].ends_at});fail=false;await s.submit();assert.equal(s.calls.length,3);assert.equal(s.calls[2].data.p_user,'u2');s.dom.window.close();
});
test('busy operation prevents resubmit and escape, then restores controls',async()=>{
 const s=setup();let release;s.w.mutation=async(action,data)=>{s.calls.push({action,data});await new Promise(r=>release=r);};s.mount('exams',[exam('1')]);s.pick();await s.choose('publish');s.w.$('bulkForm').dispatchEvent(new s.w.Event('submit',{cancelable:true}));await tick();assert(s.w.$('bulkSave').disabled);assert(s.w.$('trackSel').disabled);const cancel=new s.w.Event('cancel',{cancelable:true});s.w.$('editor').dispatchEvent(cancel);assert(cancel.defaultPrevented);s.w.$('bulkForm').dispatchEvent(new s.w.Event('submit'));assert.equal(s.calls.length,1);release();await tick();assert(!s.w.$('trackSel').disabled);s.dom.window.close();
});
test('reserve keeps hash guards and validates reason; group plans preserve daily lessons',async()=>{
 const s=setup();s.mount('reserve',[{id:'q',code:'<img src=x onerror=x>',assets_hash:'guard'}]);s.pick();await s.choose('reserve');assert.equal(s.w.$('editor').querySelector('img'),null);await s.submit();assert.equal(s.calls.length,0);s.w.$('bulkReason').value='Save for another trial';await s.submit();assert.equal(s.calls[0].action,'staff_question_reserve');assert.equal(s.calls[0].data.p_expected_hash,'guard');assert.equal(s.calls[0].data.p_reserve,true);s.dom.window.close();
 const p=setup('instructor');p.mount('plans',[{id:'g',name:'Group',plan_version:4,daily_lessons:['Algebra'],target_exam_date:'2026-11-07',course_starts_on:null,course_ends_on:null,teaching_plan:'Old'}]);p.pick();await p.choose('text');p.w.$('bulkPlanText').value='New workshop';await p.submit();assert.equal(p.calls[0].data.p_expected_version,4);assert.equal(p.calls[0].data.p_data.teaching_plan,'New workshop');assert.equal(p.calls[0].data.p_data.daily_lessons[0],'Algebra');p.dom.window.close();
});
test('real exam view mounts bulk controls and filtered selections use the original IDs',async()=>{
 const s=setup(),html=read('admin.html');s.w.getRows=async t=>t==='exams'?['1','2'].map(id=>({...exam(id),assessment_type:'quiz',question_ids:['q'],duration_seconds:600,created_at:''})):[];s.w.wrapTable=t=>'<div class="table-wrap">'+t+'</div>';s.w.sortText=(a,b)=>a.localeCompare(b);s.w.eval(html.slice(html.lastIndexOf('async function exams(){'),html.indexOf('async function assignExam(')));await s.w.exams();assert.equal(s.w.document.querySelectorAll('[data-bulk-pick]').length,2);s.pick();s.w.$('examSearch').value='Exam 2';s.w.$('examSearch').oninput();assert.match(s.query('[data-bulk-count]').textContent,/2 selected · 1 on this page/);await s.choose('unpublish');await s.submit();assert.equal(s.calls.length,2);s.dom.window.close();
});
test('served bulk files and hook order match source; inline scripts remain parseable',()=>{
 for(const f of ['admin.html','admin-bulk.js','admin-bulk.css','portal-management.js','admin-bank.js'])assert.equal(read(f),fs.readFileSync('dist/'+f,'utf8'));
 const html=read('admin.html'),dom=new JSDOM(html);for(const script of dom.window.document.querySelectorAll('script:not([src])'))new(require('node:vm').Script)(script.textContent);assert.equal(dom.window.document.querySelectorAll('script[src*="admin-bulk.js"]').length,1);assert(html.indexOf('/portal-management.js')<html.indexOf('/admin-bulk.js'));dom.window.close();
});
