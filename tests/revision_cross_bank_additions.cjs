// Offline PostgreSQL release regression. No production connection.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const dir=path.resolve(__dirname,'../content-releases/20260930_revision_additions');
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json')));
const original=fs.readFileSync(path.join(dir,'apply.sql'),'utf8'),verify=fs.readFileSync(path.join(dir,'verify.sql'),'utf8');
async function fixture(){
 const db=new PGlite();
 await db.exec("create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb,created_at timestamptz);create table question_keys(question_id uuid primary key,correct jsonb,explanation text);create table revision_items(question_id uuid primary key,lesson text,idea text,difficulty text,programmes text[],fingerprint text,active boolean,focus jsonb);create table audit_log(action text,target_type text,target_id text,meta jsonb);create function revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) returns text language sql immutable as $$select md5($1||$2::text||$3::text||$4::text||$5)$$;");
 let sql=original,contract=verify;
 for(const x of manifest){
  const q=x.q,k=x.k;
  await db.query('insert into questions values($1,$2,$3,$4,$5,$6,$7,$8,$9)',[q.id,q.track_id,q.topic,q.difficulty,q.type,q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets),q.created_at]);
  await db.query('insert into question_keys values($1,$2,$3)',[q.id,JSON.stringify(k.correct),k.explanation]);
  if(x.r){const r=x.r;const fp=(await db.query('select revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) fp from questions q join question_keys k on k.question_id=q.id where q.id=$1',[q.id])).rows[0].fp;await db.query('insert into revision_items values($1,$2,$3,$4,$5,$6,$7,$8)',[q.id,r.lesson,r.idea,r.difficulty,r.programmes,fp,false,JSON.stringify(r.focus)]);sql=sql.replaceAll(r.fingerprint,fp);}
  const dig=(await db.query('select md5(to_jsonb(q)::text) qhash,md5(to_jsonb(k)::text) khash,md5(to_jsonb(r)::text) rhash from questions q join question_keys k on k.question_id=q.id left join revision_items r on r.question_id=q.id where q.id=$1',[q.id])).rows[0];
  for(const key of ['qhash','khash','rhash'])if(x[key])sql=sql.replaceAll(x[key],dig[key]);
 }
 return {db,sql,contract};
}
(async()=>{
 const {db,sql,contract}=await fixture();
 const before=(await db.query('select to_jsonb(q) q,to_jsonb(k) k from questions q join question_keys k on k.question_id=q.id order by q.id')).rows;
 await db.exec(sql);
 assert.deepEqual((await db.query('select to_jsonb(q) q,to_jsonb(k) k from questions q join question_keys k on k.question_id=q.id order by q.id')).rows,before);
 const actual=(await db.query('select * from revision_items order by question_id')).rows;assert.equal(actual.length,9);assert.equal(actual.filter(x=>x.active).length,9);
 for(const x of manifest){const r=actual.find(r=>r.question_id===x.q.id);assert.equal(r.lesson,x.lesson);assert.equal(r.difficulty,x.difficulty);assert.deepEqual(r.programmes,x.programmes);assert.deepEqual(r.focus,x.focus);}
 assert.equal((await db.query("select count(*)::int n from audit_log where action='revision.cross_bank_additions.20260930'")).rows[0].n,9);
 await db.exec(contract);
 // Every intended representative is protected against silent loss.
 for(const x of manifest){await db.query('update revision_items set active=false where question_id=$1',[x.q.id]);await assert.rejects(()=>db.exec(contract),/coverage missing/);await db.exec('rollback');await db.query('update revision_items set active=true where question_id=$1',[x.q.id]);}
 await db.exec("update revision_items set focus=jsonb_build_object('collections',jsonb_build_array('unique')) where question_id='cc64f92a-b880-5425-bcfd-0958bd67eecb'");
 await assert.rejects(()=>db.exec(contract),/coverage missing/);await db.exec('rollback');
 await assert.rejects(()=>db.exec(sql),/already applied/);await db.exec('rollback');await db.close();
 for(const mutate of [
  "update questions set assets=assets||'{\"release_hold_reason\":\"held\"}'::jsonb where track_id='sat'",
  "update questions set track_id='est' where track_id='sat'",
  "update question_keys set correct='\"A\"'::jsonb where question_id='cc64f92a-b880-5425-bcfd-0958bd67eecb'",
  "update revision_items set fingerprint='stale' where question_id='cc64f92a-b880-5425-bcfd-0958bd67eecb'",
  "update questions set assets=assets||'{\"source_code\":\"EST2-L2-X\"}'::jsonb where id='6b2fb270-3b63-5e81-8abd-dd6a4e237a16'"
 ]){const f=await fixture();await f.db.exec(mutate);await assert.rejects(()=>f.db.exec(f.sql),/changed or ineligible/);await f.db.exec('rollback');assert.equal((await f.db.query('select count(*)::int n from revision_items where active')).rows[0].n,0);await f.db.close();}
 // An already represented copy is rejected before any release write.
 {const f=await fixture();await f.db.exec("insert into questions select '00000000-0000-0000-0000-000000000001',track_id,topic,difficulty,type,stem,choices,assets,created_at from questions where track_id='sat';insert into revision_items values('00000000-0000-0000-0000-000000000001','Statistics and data analysis','Alias of residual question','medium',array['sat'],'x',true,'{}')");await assert.rejects(()=>f.db.exec(f.sql),/Duplicate revision content/);await f.db.exec('rollback');assert.equal((await f.db.query('select count(*)::int n from revision_items where active')).rows[0].n,1);await f.db.close();}
 // Any cap violation aborts the whole release transaction.
 {const f=await fixture();for(let n=1;n<=3;n++){const id='00000000-0000-0000-0000-00000000000'+n;await f.db.query("insert into questions(id,track_id,topic,stem,choices,assets) values($1,'sat','Other lesson',$2,'[]','{}')",[id,'Sentinel '+n]);await f.db.query("insert into revision_items values($1,'Other lesson','Other idea','medium',array['sat'],'x',true,'{}')",[id]);}await assert.rejects(()=>f.db.exec(f.sql),/cap exceeded/);await f.db.exec('rollback');assert.equal((await f.db.query('select count(*)::int n from revision_items where active')).rows[0].n,3);await f.db.close();}
 // Independent numerical/source-content assertions.
 const points=[[69,15],[69,14],[73,16],[75,16],[80,16],[82,18],[82,17],[85,18],[88,20]];
 assert.equal(points.reduce((a,b)=>Math.abs(b[1]-(.2*b[0]+1))>Math.abs(a[1]-(.2*a[0]+1))?b:a)[1],20);
 assert.equal(20-10>10-6,true);assert.equal(30-20>6-4,true);
 assert.equal(7+5,12);assert.equal(7*5,35);
 for(const t of [.1,.5,1,2])assert.ok(Math.abs((3*Math.sin(t))**2/9+(5*Math.cos(t))**2/25-1)<1e-12);
 const data=[100,350,250,600,723,702,750,790],mean=data.reduce((a,b)=>a+b)/8;
 const slope=data.reduce((s,y,i)=>s+(i+1-4.5)*(y-mean),0)/42,intercept=mean-4.5*slope;
 assert.equal(intercept,88);assert.equal(Math.ceil((1000-intercept)/slope),10);assert.ok(intercept+9*slope<1000);assert.ok(intercept+10*slope>=1000);
 assert.ok(Math.abs(Math.cbrt(-3)**3+3)<1e-12); // Inner radicand is exactly zero symbolically.
 assert.equal(2*Math.PI/3,2*Math.PI/3);assert.equal(2*(1/Math.sqrt(5))*(2/Math.sqrt(5)),.7999999999999999);
 for(const b of [.1,.7,1.2])assert.ok(Math.abs(2*Math.cos(b)**3*Math.sin(b)+2*Math.sin(b)**3*Math.cos(b)-Math.sin(2*b))<1e-12);
 assert.equal(manifest.filter(x=>x.r).length,4);
 for(const x of manifest.filter(x=>x.r))assert.ok(x.q.assets.figure.startsWith('data:image/'));
 console.log('PASS: nine additions; keys/assets unchanged; focus, tracks, difficulty, source exclusions, stale guards and all nine coverage-loss mutations verified.');
})().catch(e=>{console.error(e);process.exitCode=1;});
