// Disposable PostgreSQL; no network or real users.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');const db=new PGlite();
const read=p=>fs.readFileSync(p,'utf8'),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const scalar=async(s,a=[])=>Object.values((await db.query(s,a)).rows[0])[0];
const claims=async n=>db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:id(n)})]);
const page=async(track='est',scope='questions',search='',lesson='',status='',sort='priority',n=0,size=50)=>scalar('select admin_bank_page($1,$2,$3,$4,$5,$6,$7,$8)',[track,scope,search,lesson,status,sort,n,size]);
async function main(){
 for(const p of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(p).replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec("create function staff_can_touch_track(text) returns boolean language sql as $$select true$$;");
 await db.exec(read('supabase/sql/est_source_review.sql'));
 for(const [n,role,status] of [[1,'admin','active'],[2,'instructor','active'],[3,'student','active'],[4,'admin','suspended']]){await db.query('insert into auth.users(id) values($1)',[id(n)]);await db.query('insert into profiles(id,role,status) values($1,$2,$3)',[id(n),role,status]);}
 await db.exec("insert into tracks(id,name) values('est','EST I'),('sat','SAT');");await db.query("insert into instructor_tracks values($1,'est')",[id(2)]);
 for(let n=100;n<231;n++){
  const assets={figure:['data:image/png;base64,'+'A'.repeat(30000)],lesson_subtopic:'Specific skill',source_code:'CODE-'+n,...(n===100?{release_hold_reason:'Ambiguous source'}:n===101?{lesson_subtopic:'Needs classification'}:n===102?{answer_review_status:'independently_solved',verified_release:'test'}:n===103?{verified_release:'test'}:n===230?{bank_removed:true}:{})};
  await db.query('insert into questions(id,track_id,topic,stem,choices,assets) values($1,$2,$3,$4,$5::jsonb,$6::jsonb)',[id(n),n===229?'sat':'est','Algebra',n===104?'Literal 50% _ sample':'Synthetic question '+n,JSON.stringify([{key:'A',text:'1'},{key:'B',text:'2'}]),JSON.stringify(assets)]);
  if(n!==105)await db.query('insert into question_keys values($1,$2::jsonb,$3)',[id(n),'"A"','Solution']);
 }
 for(let n=1;n<3;n++)await db.query("insert into exams(track_id,title,duration_seconds,question_ids,is_published) values('est','Fixture',600,$1::uuid[],true)",[[id(106),id(100)]]);
 await db.query("insert into est_source_review(id,track_id,source_document,source_code,source_page,source_section,review_status,question_id,image_path,image_key_base64,image_iv_base64,image_sha256) values('held','est','PDF','HOLD',1,'Algebra','ready',$1,'image','secret','iv','sha'),('good','est','PDF','GOOD',2,'Algebra','ready',$2,'image','secret','iv','sha'),('fragment','est','PDF','FRAGMENT',3,'Algebra','incomplete',null,'image','secret','iv','sha')",[id(100),id(106)]);
 await db.exec(read('supabase/sql/question_eligibility_core.sql'));await db.exec(read('supabase/sql/admin_bank_page.sql'));
 await claims(1);const first=await page();assert.equal(first.total,129);assert.equal(first.items.length,50);assert.equal(first.items[0].question_id,id(100));assert.equal(first.items[1].question_id,id(105));assert.equal(first.items[2].question_id,id(101));assert.equal(first.summary.unclassified,1);assert.equal(first.summary.independently_solved,1);
 assert.ok(JSON.stringify(first).length<60000);assert.ok(!JSON.stringify(first).includes('data:image'));assert.ok(first.items.every(q=>!('correct'in q)&&!('assets'in q)));
 const all=[...first.items,...(await page('est','questions','','','','priority',1)).items,...(await page('est','questions','','','','priority',2)).items];assert.equal(new Set(all.map(q=>q.entry_id)).size,129);assert.equal((await page()).items[0].entry_id,first.items[0].entry_id);
 assert.equal((await page('est','questions','50% _')).total,1);assert.equal((await page('est','questions','%')).total,1);assert.equal((await page('est','questions',id(106))).total,1);
 assert.equal((await page('est','questions','','','review')).total,2);assert.equal((await page('est','questions','','','ready')).total,127);assert.equal((await page('est','questions','','','unclassified')).total,1);assert.equal((await page('est','questions','','','source_checked')).total,1);
 const source=await page('est','source');assert.equal(source.total,3);assert.equal(source.items.filter(q=>q.ready).length,1);assert.ok(!JSON.stringify(source).includes('secret'));assert.equal(source.items.find(q=>q.entry_id==='held').ready,false);
 await claims(2);assert.equal((await page()).total,129);await assert.rejects(()=>page('sat'),/forbidden_track/);
 for(const n of [3,4]){await claims(n);await assert.rejects(()=>page(),/forbidden/);}await db.exec("select set_config('request.jwt.claims','{}',false)");await assert.rejects(()=>page(),/forbidden/);
 await claims(1);for(const args of [['est','bad'],['est','questions','','','','priority',-1],['est','questions','','','','priority',0,101],['est','questions','','','','invalid'],['est','questions','x'.repeat(201)]])await assert.rejects(()=>page(...args),/invalid_bank_filter/);
 assert.equal(await scalar("select has_function_privilege('anon','public.admin_bank_page(text,text,text,text,text,text,integer,integer)','execute')"),false);
 // A stale admin claim cannot revive a suspended account.
 await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:id(4),user_role:'admin'})]);await assert.rejects(()=>page(),/forbidden/);
 console.log('PASS: complete stable pagination, literal search, live holds, review ranking, source eligibility, bounded metadata, no keys/assets, instructor scope, suspended/student/anonymous denial.');await db.close();
}main().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
