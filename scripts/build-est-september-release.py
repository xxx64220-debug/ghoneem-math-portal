"""Build the next insert-only EST release from visually checked original crops."""
from pathlib import Path
from collections import Counter,defaultdict
import json,uuid,shutil,hashlib,random
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'content/est-september-2026';OUT.mkdir(exist_ok=True)
SCRATCH=Path('/workspace/scratch/861668d2e749')
SOURCE=OUT/'source-review.json'
if not SOURCE.exists():
 shutil.copy2(SCRATCH/'output/EST-Remaining-Questions-Review/remaining-review.json',SOURCE)
rows=json.loads(SOURCE.read_text());bycode={q['code']:q for q in rows}
duplicates={'HOA 021':'FA 034','HOA 023':'FA 044','HOA 024':'FA 020','HOA 027':'AAF 023','HOA 030':'FA 053','HOA 031':'FA 043','HOA 058':'FA 072','HOA 073':'FA 033','HOA 080':'FA 032','PSD 088':'AAF 047','PSD 092':'DAP 058','PAM 013':'AAF 049','PAM 016':'FA 058','PAM 025':'FA 059','PAM 038':'AAF 052','MIX 009':'DAP 039'}
holds={'PSD 202':'A company-wide 20% does not require 20% in each department; a department may have zero developers. The prior answer60 assumed an unstated per-department condition.',
 'MIX 024':'The stem ends after “which of the following is in the”; restore the missing words.',
 'MIX 025':'Choice C numerator is missing/obscured. Restore all choices before release.'}
topics={}
def group(domain,topic,codes):
 for short in codes.split():
  code=short[:3]+' '+short[3:]
  assert code not in topics,code
  topics[code]=(domain,topic)
group('FA','Inequalities and systems','HOA007 HOA013 HOA037 HOA060 PSD087 MIX043')
group('FA','Absolute value','HOA068 HOA176 HOA228 HOA238')
group('FA','Equations and expressions','HOA061 HOA096 HOA106 HOA133 HOA210 HOA234 HOA236 PSD101 PSD188 MIX003 MIX016 MIX059')
group('FA','Lines and linear models','HOA049 HOA055 HOA059 HOA141 HOA143 HOA214 PSD102')
group('FA','Systems of equations','HOA056 HOA057 HOA220 HOA226 PSD074 PSD079 PSD187 PSD201')
group('AAF','Exponents and radicals','HOA016 HOA022 HOA048 HOA074 PSD033 MIX045 MIX061')
group('AAF','Quadratics','HOA039 HOA046 HOA094 HOA135 HOA145 PSD070 PAM032 PAM046 PAM048 PAM049 PAM074 MIX010 MIX023')
group('AAF','Complex numbers','HOA062')
group('AAF','Polynomials','HOA063 HOA235 PAM061 PAM062 PAM067 PAM077')
group('AAF','Rational expressions and formulas','PAM026 PAM087')
group('AAF','Functions','HOA206 PAM019 PAM075 PAM089 PAM093 MIX050')
group('DAP','Ratios, rates and variation','HOA132 PSD077 PSD139 PSD177 PSD178 PSD184 PSD189 PSD203 PSD204 PSD206 PSD218')
group('DAP','Percentages and interest','PSD065 PSD071 PSD103 PSD107 PSD109 PSD110 PSD220 PSD222')
group('DAP','Probability and counting','PSD083 PSD111 PSD146 PSD219 PSD221 MIX001')
group('DAP','Statistics','PSD003 PSD061 PSD115 PSD142')
group('DAP','Graphs and data interpretation','PSD008 PSD075 PAM052')
group('GT','Circles','HOA070 GTC021 GTC035 GTC059')
group('GT','Area and volume','GTC011 GTC038 GTC046 GTC075')
group('GT','Coordinate geometry','HOA215 GTC039 GTC060')
group('GT','Angles, triangles and trigonometry','GTC036 GTC041 GTC071 GTC072')
eligible=[q for q in rows if q['status']=='worked' and q['code'] not in duplicates and q['code'] not in holds]
assert {q['code'] for q in eligible}==set(topics),({q['code'] for q in eligible}-set(topics),set(topics)-{q['code'] for q in eligible})
def ident(kind,code):return str(uuid.uuid5(uuid.NAMESPACE_URL,f'ghoneem:est-september-2026:{kind}:{code}'))
assetsdir=ROOT/'web/exams/est-september-2026';assetsdir.mkdir(parents=True,exist_ok=True)
questions=[]
for r in eligible:
 code=r['code'];domain,topic=topics[code]
 src=SCRATCH/'est-source-crops'/r['source_image_filename']
 target=assetsdir/r['source_image_filename']
 if src.exists():shutil.copy2(src,target)
 assert hashlib.sha256(target.read_bytes()).hexdigest()==r['source_image_sha256'],code
 explanation=r['explanation']
 if code=='MIX 045':
  explanation='The source contains a CUBE root. Cube both sides of −x = ∛x: −x³ = x, so x(x² + 1) = 0. The only real solution is x = 0, which satisfies the original equation. Therefore C.'
 # Insert spaces around digits after prose words where older working notes were compact.
 import re
 explanation=re.sub(r'\b([A-Za-z]{2,})(?=\d)',r'\1 ',explanation)
 qtype='mcq' if r['answer'] in list('ABCD') else 'grid_in'
 asset={'source_bank':'est-september-2026','source_code':code,'source_document':r['source_pdf'],'source_page':r['pdf_page_1_based'],
  'domain':domain,'subtopic':topic,'image':'https://math.portal.ghoneem.com/exams/est-september-2026/'+target.name,
  'image_alt':f'Original question {code}, including its complete answer choices and any diagram or table.',
  'source_question':code,'source_image_sha256':r['source_image_sha256'],
  'reference':'https://math.portal.ghoneem.com/exams/est-march-2026/reference.png'}
 questions.append({'id':ident('question',code),'track_id':'est','topic':domain+' · '+topic,'difficulty':'medium','type':qtype,
  'stem':f'{code} — Answer the original question below.',
  'choices':[{'key':k,'text':'Option '+k+' in the original question'} for k in 'ABCD'] if qtype=='mcq' else [],
  'assets':asset,'correct':r['answer'],'explanation':explanation})
 r['deployment_ready']=True;r['release_question_id']=questions[-1]['id'];r['release_bank']='est-september-2026'
for code,canonical in duplicates.items():bycode[code]['semantic_duplicate_of']=canonical
for code,reason in holds.items():
 bycode[code]['release_hold_reason']=reason;bycode[code]['deployment_ready']=False
bycode['MIX 045']['explanation']=next(q['explanation'] for q in questions if q['assets']['source_code']=='MIX 045')
bycode['PSD 202']['status']='ambiguous_distribution';bycode['PSD 202']['answer']=None
bycode['PSD 202']['explanation']=holds['PSD 202']
bydomain=defaultdict(list);bytopic=defaultdict(list)
for q in questions:bydomain[q['assets']['domain']].append(q);bytopic[q['topic']].append(q)
print('Ready domains:',{k:len(v) for k,v in bydomain.items()})
exams=[]
def exam(code,title,qs,kind):
 ids=[q['id'] for q in qs]
 assert len(ids)==len(set(ids))
 exams.append({'id':ident('exam',code),'track_id':'est','title':title,'duration_seconds':4500 if kind=='full_exam' else 90*len(ids),
  'question_ids':ids,'shuffle':False,'review_policy':'full_review','max_attempts':1,'is_published':False,
  'is_full_length':kind=='full_exam','assessment_type':kind,'scoring_map':None})
rng=random.Random(20260911)
for qs in bydomain.values():rng.shuffle(qs)
for i in range(2):
 paper=[]
 for domain,quota in [('FA',15),('DAP',15),('AAF',15),('GT',5)]:
  assert len(bydomain[domain])>=2*quota,(domain,len(bydomain[domain]))
  paper+=bydomain[domain][i*quota:(i+1)*quota]
 rng.shuffle(paper)
 exam(f'full-{i+6}',f'EST Math 1 — Question Bank Practice {i+6:02}',paper,'full_exam')
for topic,qs in sorted(bytopic.items()):
 exam('lesson-'+topic,'EST — '+topic+' — New bank lesson exam',qs,'lesson_exam')
 if len(qs)>=5:exam('quiz-'+topic,'EST — '+topic+' — New bank quick quiz',qs[:5],'quiz')
assert len({q for e in exams[:2] for q in e['question_ids']})==100
def dump(name,obj):(OUT/name).write_text(json.dumps(obj,indent=2,ensure_ascii=False))
dump('release-bank.json',{'questions':questions,'exams':exams})
dump('source-review.json',rows)
dump('release-audit.json',{'date':'2026-09-11','questions':len(questions),'domains':{d:len(qs) for d,qs in bydomain.items()},
 'exams':dict(Counter(e['assessment_type'] for e in exams)),
 'semantic_duplicates_skipped':duplicates,'source_holds':holds,
 'visual_review':'All selected source crops reinspected with their full stems and A–D choices. Original PNG bytes preserved.',
 'key_correction':'MIX 045 uses a cube root, not a square root; answer C remains unchanged and explanation corrected.',
 'format':'Two disjoint 50-question papers, 4500 seconds, 15 FA /15 DAP /15 AAF /5 GT. Calculator allowed throughout. Practice raw scores; no official score conversion.'})
for name in ['worked-review.tsv','graph-review.tsv','algebra-review.tsv','verify_worked.py','verify_graph.py','verify_algebra.py']:
 p=SCRATCH/'tmp/est-analysis'/name
 if p.exists():shutil.copy2(p,OUT/name)
# Public deployment output mirrors the established static web directory.
shutil.copytree(assetsdir,ROOT/'dist/exams/est-september-2026',dirs_exist_ok=True)
print('Prepared',len(questions),'new questions and',len(exams),'assessments')
