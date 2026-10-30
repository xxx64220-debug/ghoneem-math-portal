const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module'),{JSDOM}=require('./english-runtime/node_modules/jsdom');
const id='00000000-0000-4000-8000-000000000103',details={action:'submit',request_id:id,username:'new.student',full_name:'New Student',password:'secure-example-2026',track_id:'sat',phone:'',group_note:''};
function edge({rate=true,completeError=false,committed=false,prior=false,authError=false,authCode='email_exists',priorAfterCreate=false,readError=false}={}){
 let handler,createdOnce=false;const calls=[];class ApiError extends Error{constructor(m,status=400){super(m);this.status=status;}}
 const db={from(table){let filters={},selected='';const q={select(c){selected=c;return q},eq(k,v){filters[k]=v;return q},order(){return q},range(){return q},async maybeSingle(){return {data:table==='tracks'?{id:'sat'}:prior||priorAfterCreate&&createdOnce?{username:'new.student',status:'pending'}:committed&&selected==='user_id'?{user_id:'created-user'}:null,error:readError&&table!=='tracks'?{message:'constraint rejected',code:'23514'}:null}},then(resolve){return Promise.resolve({data:table==='tracks'?[{id:'sat',name:'SAT Math'}]:[],count:0}).then(resolve)}};calls.push({table,filters});return q},rpc:async(name,args)=>{calls.push({name,args});return name==='registration_rate_limit'?{data:rate}:name==='registration_complete'?{error:completeError?{message:'constraint rejected',code:'23514'}:null}:{data:{status:'approved'}};},auth:{admin:{createUser:async data=>{createdOnce=true;calls.push({create:data});return {data:{user:authError?null:{id:'created-user'}},error:authError?{code:authCode}:null}},deleteUser:async user=>{calls.push({delete:user});return {};}}}};
 vm.runInNewContext(stripTypeScriptTypes(fs.readFileSync('supabase/functions/student-registration/index.ts','utf8').replace(/^import .*;\n/m,'')),{Deno:{serve:h=>handler=h,env:{get:()=>undefined}},serve:h=>h,admin:()=>db,ApiError,crypto,TextEncoder,json:(data,status=200)=>({data,status}),requireAdmin:async req=>{if(req.headers.get('Authorization')!=='Bearer admin')throw new ApiError('forbidden',403);return {id:'verified-admin'};}});
 return {calls,call:(body,token)=>handler(new Request('https://test.invalid',{method:body?'POST':'GET',headers:{'content-type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),'x-forwarded-for':'192.0.2.1'},body:body?JSON.stringify(body):undefined}))};
}
test('public submission passes password only to Auth and cannot choose role/access',async()=>{const s=edge();assert.equal((await s.call({...details,role:'admin',status:'active',tracks:['est']})).status,201);const create=s.calls.find(c=>c.create).create;assert.equal(create.email,'new.student@students.ghoneem-math.com');assert.equal(create.password,details.password);const complete=s.calls.find(c=>c.name==='registration_complete').args;assert(!JSON.stringify(complete).includes(details.password));assert(!JSON.stringify(complete).includes('admin'));assert(!s.calls.some(c=>c.name==='enrol_student'));});
test('anonymous and students cannot list or review',async()=>{for(const action of ['list','review'])for(const token of [undefined,'student']){const s=edge();await assert.rejects(()=>s.call({action,id,data:{}},token),e=>e.status===403);assert(!s.calls.length);}const s=edge();await s.call({action:'review',id,data:{decision:'approved'}},'admin');assert.equal(s.calls[0].args.p_actor,'verified-admin');});
test('invalid inputs, bots and rate limits fail before account creation',async()=>{for(const patch of [{password:'short'},{username:'bad@username'},{full_name:'X'},{website:'spam'},{password:'أ'.repeat(40)},{group_note:'x'.repeat(6500)}]){const s=edge();await assert.rejects(()=>s.call({...details,...patch}));assert(!s.calls.some(c=>c.create));}const s=edge({rate:false});await assert.rejects(()=>s.call(details),e=>e.status===429);assert(!s.calls.some(c=>c.create));await assert.rejects(()=>edge({authError:true}).call(details),/username_unavailable/);});
test('retry keeps one account and cleanup does not delete a committed application',async()=>{const s=edge({prior:true});assert((await s.call(details)).data.submitted);assert(!s.calls.some(c=>c.create));const failed=edge({completeError:true});await assert.rejects(()=>failed.call(details),/registration_unavailable/);assert(failed.calls.some(c=>c.delete==='created-user'));const lost=edge({completeError:true,committed:true});assert((await lost.call(details)).data.submitted);assert(!lost.calls.some(c=>c.delete));});
const tick=()=>new Promise(r=>setImmediate(r));
test('form checks confirmation, submits, clears passwords and stores only retry receipt',async()=>{const dom=new JSDOM(fs.readFileSync('web/register.html','utf8'),{url:'https://portal.test/register.html',runScripts:'outside-only'}),w=dom.window,calls=[];w.TextEncoder=TextEncoder;w.fetch=async(url,opts)=>{if(opts.method==='POST'){calls.push(JSON.parse(opts.body));return {ok:true,json:async()=>({submitted:true})}}return {ok:true,json:async()=>({tracks:[{id:'sat',name:'SAT Math'}]})}};w.eval(fs.readFileSync('web/registration.js','utf8'));await tick();const $=id=>w.document.getElementById(id);$('fullName').value='New Student';$('username').value='New.Student';$('password').value=details.password;$('confirmPassword').value='mismatch';$('course').value='sat';await $('registrationForm').onsubmit({preventDefault(){}});assert.equal(calls.length,0);assert.match($('feedback').textContent,/do not match/);$('confirmPassword').value=details.password;await $('registrationForm').onsubmit({preventDefault(){}});assert.equal(calls[0].username,'new.student');assert.equal($('password').value,'');assert.equal($('confirmPassword').value,'');assert($('registrationForm').hidden);assert(!$('success').hidden);assert(!w.sessionStorage.getItem('registration-retry').includes(details.password));dom.window.close();});
test('registration source and served assets match',()=>{for(const dir of ['portal-static','dist'].filter(d=>fs.existsSync(d+'/admin.html')))for(const f of ['register.html','registration.js','registration.css','registration-admin.js','student-management.js','index.html','admin.html'])assert.equal(fs.readFileSync('web/'+f,'utf8'),fs.readFileSync(dir+'/'+f,'utf8'));assert.match(fs.readFileSync('web/index.html','utf8'),/href="\/register.html"/);});
test('admin review escapes student data and saves course/group/dates in one operation',async()=>{
 const dom=new JSDOM('<main id="view"></main><dialog id="editor"></dialog>',{url:'https://portal.test/admin.html',runScripts:'outside-only'}),w=dom.window,calls=[];let save;
 w.ST={view:'registrations',track:'',me:{id:'admin',role:'admin'},tracks:[{id:'sat',name:'SAT Math'},{id:'est',name:'EST Math'}]};w.$=id=>w.document.getElementById(id);w.esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));w.val=id=>w.$(id).value;
 const row={id,user_id:'user',full_name:'Student <img src=x>',username:'new.student',track_id:'sat',group_note:'November',phone:'',status:'pending',created_at:'2026-10-26T08:00:00Z'};
 w.fn=async(name,{body})=>{calls.push(body);return {ok:true,json:body.action==='list'?{items:[row],total:1}:{status:'approved'}}};w.select=(id,label,options,value='')=>`<label>${label}<select id="${id}">${options.map(([k,v])=>`<option value="${k}" ${k===value?'selected':''}>${v}</option>`).join('')}</select></label>`;w.field=(id,label,value='',type='text')=>`<label>${label}<input id="${id}" value="${value}" type="${type}"></label>`;w.wrapTable=s=>s;
 w.dialog=(title,html,onSave)=>{w.$('editor').innerHTML=html;save=onSave};w.getRows=async()=>[{id:'sat-group',track_id:'sat',name:'November'},{id:'est-group',track_id:'est',name:'Alex'}];w.render=async()=>{};w.syncAdminNavigation=()=>{};
 w.eval(fs.readFileSync('web/registration-admin.js','utf8'));await w.render();assert.equal(w.$('view').querySelector('img'),null);assert(w.$('registrationLink').value.endsWith('/register.html'));await w.document.querySelector('[data-approve-registration]').onclick();assert.equal(w.$('registrationGroup').querySelectorAll('option').length,2);w.$('registrationGroup').value='sat-group';w.$('registrationStart').value='2030-01-01T12:00';w.$('registrationEnd').value='2030-11-30T12:00';await save();const review=calls.find(x=>x.action==='review');assert.equal(review.data.track_id,'sat');assert.equal(review.data.group_id,'sat-group');assert(review.data.ends_at.startsWith('2030-11-30'));dom.window.close();
});

test('replaying a completed request does not create accounts or consume rate quota',async()=>{
 const s=edge({prior:true,rate:false});assert((await s.call(details)).data.submitted);
 assert(!s.calls.some(c=>c.create||c.name==='registration_rate_limit'));
});
test('concurrent duplicate settles from receipt; infrastructure failure is not username conflict',async()=>{
 const race=edge({authError:true,priorAfterCreate:true});assert((await race.call(details)).data.submitted);
 for(const code of ['unexpected_failure','over_request_rate_limit'])await assert.rejects(()=>edge({authError:true,authCode:code}).call(details),e=>e.status===503&&e.message==='registration_unavailable');
 await assert.rejects(()=>edge({authError:true,authCode:'weak_password'}).call(details),e=>e.status===400&&e.message==='weak_password');
});
test('invalid phone, track and control characters cannot create accounts',async()=>{
 for(const patch of [{phone:'<script>'},{phone:123},{track_id:[]},{track_id:''},{full_name:'Name\u0000Other'},{group_note:'Class\u0000Other'}]){
  const s=edge();await assert.rejects(()=>s.call({...details,...patch}));assert(!s.calls.some(c=>c.create));
 }
});
async function formFixture(post){
 const dom=new JSDOM(fs.readFileSync('web/register.html','utf8'),{url:'https://portal.test/register.html',runScripts:'outside-only'}),w=dom.window;
 w.TextEncoder=TextEncoder;w.fetch=async(url,opts)=>opts.method==='POST'?post(opts):{ok:true,json:async()=>({tracks:[{id:'sat',name:'SAT Math'}]})};
 w.eval(fs.readFileSync('web/registration.js','utf8'));await tick();const $=id=>w.document.getElementById(id);
 for(const [id,value] of Object.entries({fullName:'New Student',username:'New.Student',password:details.password,confirmPassword:details.password,course:'sat'}))$(id).value=value;
 return {dom,w,$,submit:()=>$('registrationForm').onsubmit({preventDefault(){}})};
}
test('in-flight form locks controls and prevents repeated Enter submissions',async()=>{
 let finish,calls=0;const f=await formFixture(()=>{calls++;return new Promise(r=>finish=r)});
 try{const first=f.submit();await tick();assert(f.$('username').disabled);assert(f.$('course').disabled);await f.submit();assert.equal(calls,1);
 finish({ok:true,json:async()=>({submitted:true})});await first;assert(f.$('registrationForm').hidden);assert.equal(f.$('password').value,'');}finally{f.dom.window.close();}
});
test('failed response is safe text and retry preserves receipt without persisting passwords',async()=>{
 const ids=[];let calls=0;const f=await formFixture(async opts=>{ids.push(JSON.parse(opts.body).request_id);calls++;return calls===1?{ok:false,json:async()=>({error:'<img src=x onerror=alert(1)>'})}:{ok:true,json:async()=>({submitted:true})};});
 try{await f.submit();assert(!f.$('username').disabled);assert.match(f.$('feedback').textContent,/temporarily unavailable/);assert.equal(f.$('feedback').querySelector('img'),null);await f.submit();assert.equal(ids[0],ids[1]);assert(!f.w.sessionStorage.getItem('registration-retry').includes(details.password));}finally{f.dom.window.close();}
});
test('registration has POST fallback so credentials never enter a URL',()=>{
 const d=new JSDOM(fs.readFileSync('web/register.html','utf8'));assert.equal(d.window.document.querySelector('form').method,'post');d.window.close();
});
test('a timed-out request unlocks the form and keeps the same receipt for retry',async()=>{
 let calls=0;const ids=[];const f=await formFixture(async opts=>{
  ids.push(JSON.parse(opts.body).request_id);if(++calls>1)return {ok:true,json:async()=>({submitted:true})};
  return new Promise((resolve,reject)=>opts.signal.addEventListener('abort',()=>reject(new f.w.DOMException('Aborted','AbortError'))));
 });
 try{const realTimer=f.w.setTimeout;f.w.setTimeout=callback=>realTimer(callback,0);await f.submit();assert(!f.$('username').disabled);assert.match(f.$('feedback').textContent,/Connection interrupted/);await f.submit();assert.equal(ids[0],ids[1]);}finally{f.dom.window.close();}
});
test('registration approval locks cancel, Escape and repeated submission, and recovers after failure',async()=>{
 const d=new JSDOM('<main id="view"></main><dialog id="editor"></dialog>',{runScripts:'outside-only',url:'https://portal.test/admin.html'}),w=d.window;let resolve,calls=0;
 w.$=id=>w.document.getElementById(id);w.render=()=>{};
 w.dialog=(title,body,onSave)=>{w.$('editor').innerHTML='<form id="editForm"><input id="testDate"><button id="editSave">Approve</button><button id="editCancel" type="button">Cancel</button></form>';w.$('editForm').onsubmit=async()=>{await onSave();};};
 // Exercise the actual wrapper with the same host-dialog contract as admin.html.
 w.eval(fs.readFileSync('web/registration-admin.js','utf8').replace(' const priorRender=render;',' window.testRegistrationDialog=registrationDialog; const priorRender=render;'));
 try{w.testRegistrationDialog('Review','',async()=>{calls++;await new Promise(r=>resolve=r);throw Error('save failed');},'Approve');
 const submit=w.$('editForm').onsubmit,first=submit({preventDefault(){}});assert(w.$('editCancel').disabled);assert(w.$('testDate').disabled);
 const cancel=new w.Event('cancel',{cancelable:true});w.$('editor').dispatchEvent(cancel);assert(cancel.defaultPrevented);
 await submit({preventDefault(){}});assert.equal(calls,1);resolve();await assert.rejects(()=>first,/save failed/);assert(!w.$('editCancel').disabled);assert(!w.$('testDate').disabled);
 }finally{d.window.close();}
});
