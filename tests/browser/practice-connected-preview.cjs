// Build an isolated browser QA page from real portal renderers. No live API or student data.
const fs=require('node:fs'),path=require('node:path');const out=process.argv[2];if(!out)throw Error('Pass an isolated preview directory');
const read=f=>fs.readFileSync(f,'utf8');fs.mkdirSync(out,{recursive:true});
for(const f of fs.readdirSync('web'))if(/\.(css|js|woff2)$/.test(f))fs.copyFileSync('web/'+f,path.join(out,f));
const bundles=read('web/practice-bundles.html').replace(/<script[^>]*src="https:\/\/cdn.jsdelivr.net\/npm\/@supabase[^>]*><\/script>/,'<script src="/__bundle-fixture.js"></script>').replace(/<script[^>]*src="\/portal-devices.js[^"]*"[^>]*><\/script>/,'').replace('<body>','<body><p style="background:#fff2ce;padding:12px">TEST PREVIEW · Synthetic account and questions · No live records</p>');
fs.writeFileSync(path.join(out,'practice-bundles.html'),bundles);fs.copyFileSync('tests/fixtures/bundle-browser-fixture.js',path.join(out,'__bundle-fixture.js'));
const index=read('web/index.html'),dashboard=read('web/student-dashboard.js'),daily=read('web/daily-challenge.js'),controls=read('web/portal-controls.js');
const renderers=dashboard.slice(dashboard.indexOf('function lessonCard'),dashboard.indexOf('function wireDashboard'))+daily.slice(daily.indexOf('function mistakesPanel'),daily.indexOf('function wireMistakes'));
const init=`
const params=new URLSearchParams(location.search),track=params.get('practice_track')||'sat';
const ST={track:{id:track,name:track.toUpperCase()},tracks:['sat','est','est2','act2','est_eng','sat_eng'].map(id=>({id,name:id.toUpperCase()}))};
const DASH={view:params.get('practice_view')||'focus',access:{practice_open:true},history:[],exams:[],dailyGroups:[],repeatQuestions:0,notebookFeedback:{},mistakePage:0,lessons:[{lesson:'Triangles and similarity',priority:'focus',seen:5,correct:2,percent:40,exam_seen:3,bundle_seen:2,last_practiced:'2026-11-13'}],mistakes:{remaining:1,mastered:0,items:[{id:'fixture',topic:'Triangles and similarity',type:'mcq',stem:'A right triangle has legs of 3 and 4. What is the hypotenuse?',choices:[{key:'A',text:'5'},{key:'B',text:'7'}],assets:{},streak:0,tries:0}]}};
const PRIORITIES={focus:['Focus first','Review the lesson, then practise.']};
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));const percentText=n=>n+'%',dateText=s=>s,figure=()=>'';
function paintDashboard(){};function paintDashboardContent(){document.getElementById('dashboardContent').innerHTML=DASH.view==='mistakes'?mistakesPanel():focusSection();}
function setDashboardView(view){DASH.view=view;paintDashboardContent();}function wireDashboard(){};function math(){};async function openTrack(t){ST.track=t;}async function openStudyLink(){};
const sb={from(){throw Error('No live data in this preview');}};
window.fetch=()=>Promise.reject(Error('No API requests in isolated preview'));
`;
fs.writeFileSync(path.join(out,'__practice-renderers.js'),init+renderers+controls.slice(controls.indexOf('function finalsExamLessons'))+'\npaintDashboardContent();');
const styles=[...index.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(x=>x[0]).join('');
const links=['focus','mistakes','finalsDiagnosis'].map((view,i)=>`<a class="btn-ghost" href="/?practice_track=sat&practice_view=${view}">${['Lesson focus','My mistakes','Diagnosis'][i]}</a>`).join(' ');
fs.writeFileSync(path.join(out,'index.html'),`<!doctype html><html data-practice-bundles-enabled="true"><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Connected practice QA</title>${styles}<link rel="stylesheet" href="/portal-responsive.css"><link rel="stylesheet" href="/portal-controls.css"></head><body><main style="max-width:1100px;margin:auto;padding:20px"><p>TEST PREVIEW · Synthetic evidence · No live records</p><nav>${links}</nav><div id="dashboardContent"></div></main><script src="/__practice-renderers.js"></script></body></html>`);
fs.writeFileSync(path.join(out,'mobile.html'),'<html><meta name="viewport" content="width=device-width,initial-scale=1"><title>390px connected practice</title><body style="margin:0;background:#ddd"><iframe title="Mobile portal" src="/?practice_track=sat&practice_view=focus" style="display:block;width:390px;height:844px;border:0;margin:auto"></iframe></body></html>');
