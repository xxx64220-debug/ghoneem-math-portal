const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');

// Load the production renderer, not a mock with the previously wrong name.
const html=readFileSync('web/index.html','utf8');
const renderer=html.slice(html.indexOf('function figure(a)'),html.indexOf('const fmt =',html.indexOf('function figure(a)')));
const esc=s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const c={esc,console,Date,setInterval(){},document:{addEventListener(){}},ST:{track:{id:'est',theme:{label:'EST'}}},DASH:{mistakesLoading:false,mistakesError:'',notebookFeedback:{}}};
vm.createContext(c);
vm.runInContext(renderer,c);
vm.runInContext(readFileSync('web/daily-challenge.js','utf8'),c);
const items=[
 {id:'q1',stem:'Graph one',type:'mcq',topic:'Functions',streak:0,choices:[{key:'A',text:'1'}],assets:{image:'https://example.test/intended-q1.png',image_alt:'First graph'}},
 {id:'q2',stem:'Graph two',type:'grid_in',topic:'Geometry',streak:1,choices:[],assets:{figure:['https://example.test/intended-q2.png','data:image/png;base64,aGVsbG8='],figure_caption:'Second graph'}},
 {id:'q3',stem:'No figure needed',type:'grid_in',topic:'Algebra',streak:0,choices:[],assets:null}
];
const verify=out=>{
 assert.equal((out.match(/<img /g)||[]).length,3);
 assert.match(out,/intended-q1\.png/);assert.match(out,/intended-q2\.png/);
 assert.ok(out.indexOf('Graph one')<out.indexOf('intended-q1.png'));
 assert.ok(out.indexOf('intended-q1.png')<out.indexOf('Graph two'));
 assert.ok(out.indexOf('Graph two')<out.indexOf('intended-q2.png'));
 assert.doesNotMatch(out,/Correct answer:/);
};
c.DASH.mistakes={remaining:3,mastered:0,items};verify(c.mistakesPanel());
c.DASH.drill={drill_id:'drill',topics:['Functions'],completed:false,questions:items};verify(c.drillPanel());
c.DASH.daily={track:'est',quiz:items,checklist:{},leaderboard:[],completed:false,streak:null};verify(c.dailyPanel());
assert.equal(c.figure({image:'javascript:alert(1)',figure:'javascript:alert(1)'}),'');
assert.equal(c.figure(null),'');
const mathCode=html.slice(html.indexOf('function math(el)'),html.indexOf('const FRIENDLY'));
c.window={renderMathInElement:true};c.renderMathInElement=(el,options)=>{c.mathOptions=options};
vm.runInContext(mathCode,c);c.math({});
assert.ok(c.mathOptions.delimiters.some(d=>d.left==='\\('&&d.right==='\\)'));
assert.ok(c.mathOptions.delimiters.some(d=>d.left==='\\['&&d.right==='\\]'));
assert.match(html,/math\(content\);/);
console.log('PASS: notebook, daily quiz and drill use the exam renderer, preserve question-to-image mapping, hide keys and recognize parenthesized math.');
