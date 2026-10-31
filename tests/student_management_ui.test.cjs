const PORTAL_STATIC=require('./public-artifact-dir.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const read=f=>fs.readFileSync('web/'+f,'utf8'),tick=()=>new Promise(r=>setImmediate(r));
function setup({role='admin',existing=false,failSave=false,failRead=false,testAccount=false}={}){
 const dom=new JSDOM('<nav id="tabs"><div class="wrap"><button data-v="students">Students</button><button data-v="subscriptions">Courses</button></div></nav><select id="adminSection"><option value="students">Students</option><option value="subscriptions">Courses</option></select><main id="view"></main><dialog id="editor"></dialog>',{runScripts:'outside-only'}),w=dom.window,calls=[];
 w.ST={view:'students',track:'sat',me:{role,id:'admin'},tracks:[{id:'sat',name:'SAT'},{id:'est',name:'EST I'},{id:'est2',name:'EST II'},{id:'est_eng',name:'English'}]};w.$=id=>w.document.getElementById(id);w.esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));w.sortText=(a,b)=>String(a).localeCompare(b);w.alert=x=>calls.push({alert:x});
 w.eval(read('admin.html').slice(read('admin.html').indexOf('const field='),read('admin.html').indexOf('function dialog(')).replace(/const (field|area|select|tracks|val|jval)=/g,'window.$1='));
 w.render=async()=>{};w.syncAdminNavigation=()=>{w.$('adminSection').value=w.ST.view;};w.students=async()=>{w.$('view').textContent='Instructor students';};w.manageUser=async u=>calls.push({legacy:u});w.mutation=async(action,data)=>calls.push({action,data});w.deleteAccount=()=>{};w.wrapTable=t=>'<div class="table-wrap">'+t+'</div>';let save;
 w.dialog=(title,body,callback)=>{save=callback;w.$('editor').innerHTML='<form><h2>'+title+'</h2>'+body+'<button id="editSave">Save</button><button id="editCancel">Cancel</button></form>';w.$('editor').open=true;};
 const courses=existing?[{user_id:'u',track_id:'sat',status:'active',payment_status:'paid',course_label:'Old course',starts_at:null,ends_at:'2026-12-01T00:00:00Z',access_version:3}]:[];
 const groups=[{id:'g',track_id:'sat',name:'Class <img src=x>'},{id:'default',track_id:'sat',name:'SAT — all students'},{id:'e',track_id:'est',name:'EST class'}];
 let profile=existing?{id:'u',full_name:'Existing',email:'u@example.test',status:'active',role:'student'}:null,members=existing?['g','default']:[],saved=false,created=false;
 w.mutation=async(action,data)=>{calls.push({action,data});if(action==='user.update'){Object.assign(profile,data);if(data.full_name)saved=true;}if(action==='enrollment.save'&&!courses.some(e=>e.track_id===data.track_id))courses.push({user_id:data.user_id,track_id:data.track_id,status:'active',payment_status:'unrecorded',course_label:'',starts_at:null,ends_at:null,access_version:0});};
 w.sb={rpc:async(name,args)=>{calls.push({name,args});if(failSave){failSave=false;return {error:{message:'Validation failure'}};}const course=courses.find(e=>e.track_id===args.p_track);Object.assign(course,args.p_data,{access_version:course.access_version+1});return {data:JSON.parse(JSON.stringify(course))};}};
 w.fn=async(name,body)=>{calls.push({fn:name,body});if(name==='admin-users'){created=true;profile={id:'new',full_name:body.body.full_name,role:'student',status:'active',email:'new@example.test'};return {ok:true,json:{user_id:'new'}};}if(name==='student-groups'){members=[...new Set([...members,...body.body.add])].filter(id=>!body.body.remove.includes(id));return {ok:true,json:{}};}};
 w.getRows=async(name,track,cols,order,key,value)=>{if(name==='profiles'&&created&&failRead){failRead=false;throw new Error('Network read failure');}const data=({profiles:profile?[profile]:[],roster:[{user_id:'u',full_name:'Student',email:'u@example.test',role:'student',status:'active',tracks:'sat',is_test:testAccount}],enrollments:key?courses:(existing?courses:[{user_id:'u',track_id:'sat',status:'paused',payment_status:'pending',course_label:'Course'}]),groups,group_members:(key?members:(existing?members:['g'])).map(group_id=>({group_id,user_id:profile?.id||'u'}))})[name]||[];return JSON.parse(JSON.stringify(data));};
 w.eval(read('student-management.js'));return {dom,w,calls,get save(){return save;},get saved(){return saved;}};
}
function enable(s,track){const card=s.w.document.querySelector('[data-student-course="'+track+'"]'),b=card.querySelector('[data-course-enabled]');b.checked=true;b.onchange();return card;}
test('creation submits account, all four subscriptions and groups through one form',async()=>{
 const s=setup();await s.w.StudentHub.open();s.w.$('studentLogin').value='new.student';s.w.$('studentPassword').value='secure-pass';s.w.$('studentName').value='New Student';
 for(const track of ['sat','est','est2','est_eng'])enable(s,track);s.w.document.querySelector('[data-student-group="g"]').checked=true;s.w.document.querySelector('[data-student-group="e"]').checked=true;s.w.$('scPayment0').value='paid';s.w.$('scLabel0').value='November';await s.save();
 const create=s.calls.find(c=>c.fn==='admin-users');assert.equal(create.body.body.role,'student');assert.deepEqual(JSON.parse(JSON.stringify(create.body.body.tracks)),[]);assert.equal(create.body.body.username,'new.student');
 const save=s.calls.find(c=>c.name==='admin_save_course_access');assert.equal(save.args.p_user,'new');assert.equal(save.args.p_expected_version,0);assert.equal(s.calls.filter(c=>c.action==='enrollment.save').length,4);assert.equal(save.args.p_data.payment_status,'paid');assert.equal(save.args.p_data.course_label,'November');assert(s.calls.find(c=>c.fn==='student-groups').body.body.add.includes('g'));assert.equal(s.calls.filter(c=>c.action==='user.update').at(-1).data.status,'active');assert.equal(s.w.$('studentPassword').value,'');assert.equal(s.w.$('editor').querySelector('img'),null);s.dom.window.close();
});
test('client validates dates before creating any account',async()=>{
 const s=setup();await s.w.StudentHub.open();s.w.$('studentName').value='Student';s.w.$('studentLogin').value='new.user';s.w.$('studentPassword').value='secure-pass';s.w.$('scStart0').value='2026-11-02T10:00';s.w.$('scEnd0').value='2026-11-01T10:00';await assert.rejects(()=>s.save(),/end must be after/);assert(!s.calls.some(c=>c.fn));s.dom.window.close();
});
test('retry after setup failure or initial state-read failure uses the created account once',async()=>{
 for(const option of ['failSave','failRead']){const s=setup({[option]:true});await s.w.StudentHub.open();s.w.$('studentLogin').value='student.test';s.w.$('studentPassword').value='secure-pass';s.w.$('studentName').value='Student';s.w.$('scLabel0').value='November';await assert.rejects(()=>s.save());assert(s.w.$('studentLogin').disabled);assert.match(s.w.$('studentSetupProgress').textContent,/Account created/);await s.save();assert.equal(s.calls.filter(c=>c.fn==='admin-users').length,1);assert(s.saved);s.dom.window.close();}
});
test('editing loads dates/payment/groups and unchecked courses pause without dropping old setup',async()=>{
 const s=setup({existing:true});await s.w.manageUser({user_id:'u',role:'student'});assert.equal(s.w.$('scPayment0').value,'paid');assert.equal(s.w.$('scLabel0').value,'Old course');assert(s.w.document.querySelector('[data-student-group="g"]').checked);const cb=s.w.document.querySelector('[data-course-enabled]');cb.checked=false;cb.onchange();await s.save();const c=s.calls.find(c=>c.name==='admin_save_course_access').args.p_data;assert.equal(c.status,'paused');assert.equal(c.payment_status,'paid');assert(c.ends_at.startsWith('2026-12-01'));assert(!s.calls.some(c=>c.fn));s.dom.window.close();
});
test('unified roster includes paused courses, subscription summary, groups and navigation',async()=>{
 const s=setup();await s.w.students();assert.match(s.w.$('view').textContent,/Students & subscriptions/);assert.match(s.w.$('view').textContent,/Paused/);assert.match(s.w.$('view').textContent,/pending/);assert.match(s.w.$('view').textContent,/Class/);assert(s.w.$('addAccount'));assert.equal(s.w.$('view').querySelector('img'),null);assert(s.w.document.querySelector('[data-v="subscriptions"]').hidden);
 s.w.ST.view='subscriptions';s.w.syncAdminNavigation();assert.equal(s.w.$('adminSection').value,'students');s.w.$('view').innerHTML='<div class="head"><h2>Course access</h2></div>';s.w.StudentHub.decorate();assert(s.w.$('view').querySelector('[data-student-tab="students"]'));s.dom.window.close();
});
test('instructor retains scoped student list and staff accounts use their existing manager',async()=>{
 const s=setup({role:'instructor'});await s.w.students();assert.match(s.w.$('view').textContent,/Instructor students/);await assert.rejects(()=>s.w.StudentHub.open(),/admin_required/);assert.equal(s.calls.length,0);s.dom.window.close();
 const a=setup();await a.w.manageUser({user_id:'admin',role:'admin'});assert(a.calls.some(c=>c.legacy));a.dom.window.close();
});
test('source and served files match and new workspace loads before bulk selection',()=>{
 for(const f of ['student-management.js','student-management.css','admin.html','portal-management.js'])assert.equal(read(f),fs.readFileSync((PORTAL_STATIC + '/')+f,'utf8'));const h=read('admin.html');assert(h.indexOf('/portal-management.js')<h.indexOf('/student-management.js'));assert(h.indexOf('/student-management.js')<h.indexOf('/admin-bulk.js'));
});

test('preferred daily group is saved only for a selected matching membership',async()=>{
 const s=setup();await s.w.StudentHub.open();s.w.$('studentLogin').value='daily.user';s.w.$('studentPassword').value='secure-pass';s.w.$('studentName').value='Student';s.w.$('scDaily0').value='g';await assert.rejects(()=>s.save(),/checked for this student/);assert(!s.calls.some(c=>c.fn));s.w.document.querySelector('[data-student-group="g"]').checked=true;await s.save();const call=s.calls.find(c=>c.fn==='student-groups');assert.equal(call.body.body.daily_groups[0].track_id,'sat');assert.equal(call.body.body.daily_groups[0].group_id,'g');s.dom.window.close();
});

test('test account stays manageable, is labelled, and is excluded from Students filter',async()=>{
 const s=setup({testAccount:true});await s.w.students();assert.match(s.w.$('view').textContent,/TEST ACCOUNT/);assert(s.w.$('view').querySelector('[data-user="u"]'));
 s.w.$('studentFilter').value='student';s.w.$('studentFilter').onchange();await tick();assert.equal(s.w.$('view').querySelector('[data-user="u"]'),null);
 s.w.$('studentFilter').value='test';s.w.$('studentFilter').onchange();await tick();assert(s.w.$('view').querySelector('[data-user="u"]'));s.dom.window.close();
});
