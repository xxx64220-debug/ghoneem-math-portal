"""Build reviewed EST questions and deterministic, balanced practice assessments.

Only the private content/ directory contains keys. Public output contains diagrams
only. This script never writes to the live database or changes existing attempts.
"""
from pathlib import Path
from collections import Counter, defaultdict
import csv, hashlib, json, random, re, shutil, uuid

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'content/est-banks-2026'
BASE='https://ghoneem-exam-portal.xxx64220.chatgpt.site'
VERSION='ghoneem:est-reviewed-banks-2026:v1'
def identity(kind,code): return str(uuid.uuid5(uuid.NAMESPACE_URL,f'{VERSION}:{kind}:{code}'))
def dump(name,value): (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2))
raw=json.loads((OUT/'topic-questions.json').read_text())
source={q['code']:q for q in raw}
reviews={q['code']:q for q in csv.DictReader((OUT/'topic-review.tsv').open(),delimiter='\t')}
sourcekeys=json.loads((OUT/'source-keys.json').read_text())['tests']
catalogue=json.loads((OUT/'catalogue.json').read_text())
cat={(q['source'],q['code']):q for q in catalogue}
assert len(raw)==len(reviews)==250

salary='Combined monthly salaries in 2019, in thousands of dollars: Jan 2; Feb 3; Mar 2; Apr 8; May 6; Jun 4; Jul 2; Aug 1; Sep 11; Oct 9; Nov 3; Dec 6. '
gold='Average closing gold price ($): 2020: 1,771.90; 2019: 1,393.34; 2018: 1,268.93; 2017: 1,251.92; 2016: 1,158.86; 2015: 1,266.06; 2014: 1,409.51; 2013: 1,668.86. '
walk='Amir’s walking distances (m) in April 2021: Apr 1: 1,678; Apr 2: 2,091; Apr 3: 1,245; Apr 4: 1,566; Apr 5: 2,100; Apr 6: 1,989; Apr 7: 1,888. '
cars='A survey covers 80 families in each city. Number of cars: City A frequency, City B frequency — 1: 25, 20; 2: 31, 19; 3: 14, 23; 4: 8, 12; 5: 2, 6. '
spring='For a spring-mass system, T = 2π√(m/k), where T is the period, m the mass, and k the spring constant (all positive). '
context={
 'FA 011':spring, 'AAF 070':spring,
 'FA 015':'The number g of gallons remaining after driving m kilometers is g = 12 − m/20. ',
 'FA 041':'Printing n brochures costs C = 79 + 0.44n dollars. ',
 'DAP 012':salary,'DAP 014':salary,
 'DAP 026':'The graph shows new Hyundai cars (solid line) and Honda cars (dashed line) bought in country X. ',
 'DAP 033':cars,'DAP 037':gold,'DAP 056':gold,'DAP 038':walk,'DAP 040':walk,
 'DAP 068':'The graph shows observed values and fitted curves. Year 2011 is x = 0. Village B’s fitted line is y = 194.3x + 2,020.4. ',
 'DAP 071':'The scatterplot shows the numbers of laptops repaired for different companies in each year. ',
 'AAF 044':'The table gives values of f(x) = x² + 3x. ',
 'AAF 045':'The table gives values of f(x) = x² + 3x. ',
 'DAP 028':'The graph records software sales receipts in thousands of dollars over twelve months. ',
 'DAP 072':'The graph records software sales receipts in thousands of dollars over twelve months. ',
 'DAP 005':'The box plot represents the ages of actors in a TV series. ',
 'DAP 022':'The box plot represents the ages of actors in a TV series. ',
 'DAP 073':'The box plot represents the ages of actors in a TV series. ',
}
shared_figures={'FA 031':'FA 034','DAP 026':'DAP 027','DAP 063':'DAP 062',
 'DAP 064':'DAP 062','DAP 065':'DAP 062','DAP 068':'DAP 067',
 'DAP 071':'DAP 070','AAF 050':'AAF 048'}

def topic_for(domain,sub):
 s=sub.lower()
 if domain=='FA':
  if 'absolute' in s:return 'Absolute value'
  if 'inequalit' in s:return 'Inequalities and systems'
  if 'system' in s or 'simultaneous' in s:return 'Systems of equations'
  if 'linear equation' in s:return 'Equations and expressions'
  if any(x in s for x in ['slope','line','collinear','coordinate','midpoint','intercept']):return 'Lines and linear models'
  return 'Equations and expressions'
 if domain=='DAP':
  if any(x in s for x in ['probability','counting','expected']):return 'Probability and counting'
  if any(x in s for x in ['percent','interest']):return 'Percentages and interest'
  if any(x in s for x in ['variation','ratio','rate','conversion']):return 'Ratios, rates and variation'
  if any(x in s for x in ['mean','median','mode','center','quartile','box','distribution','skew','stem-and']):return 'Statistics'
  return 'Graphs and data interpretation'
 if domain=='AAF':
  if 'complex' in s:return 'Complex numbers'
  if any(x in s for x in ['radical','exponent']):return 'Exponents and radicals'
  if any(x in s for x in ['rational','rearranging','partial']):return 'Rational expressions and formulas'
  if any(x in s for x in ['quadratic','parabola']):return 'Quadratics'
  if any(x in s for x in ['polynomial','factor']):return 'Polynomials'
  return 'Functions'
 if any(x in s for x in ['circle','arc','sector']):return 'Circles'
 if any(x in s for x in ['coordinate','midpoint','distance']):return 'Coordinate geometry'
 if any(x in s for x in ['volume','prism','square','area']):return 'Area and volume'
 return 'Angles, triangles and trigonometry'

questions=[]; audit=[]
for q in raw:
 code=q['code'];review=reviews[code]
 printed=sourcekeys[str(q['source_test'])].split()[q['source_question']-1]
 entry={'source':'topic','code':code,'source_test':q['source_test'],'source_question':q['source_question'],
        'printed_key':printed,'reviewed_answer':review['answer'],'notes':[]}
 if review['answer']=='HOLD':
  entry.update(status='excluded',reason=review['explanation']);audit.append(entry);continue
 stem=re.sub(r'^\(Same [^)]*\)\.?\s*','',q['stem'])
 if code in context:
  stem=context[code]+stem;entry['notes'].append('Shared context restored and repeated with this question.')
 images=q['images']
 if code in shared_figures:
  images=source[shared_figures[code]]['images'];assert images
  entry['notes'].append('Shared source figure repeated with this question.')
 if code=='FA 009':
  stem=stem.replace('x ≠ −1','x ≠ −1 and x ≠ 0');entry['notes'].append('Explicitly excluded zero, where the original fraction is undefined.')
 if code=='FA 065':
  stem='Assume a and b are not both zero. '+stem;entry['notes'].append('Added the nondegeneracy condition required for a unique solution.')
 if code=='AAF 064':
  stem=stem.replace('y ≠ ±1','y ≠ −1, 0, 1');entry['notes'].append('Restored the missing denominator restriction y ≠ 0.')
 if code=='AAF 048':
  stem='Use the graph below. '+stem.split(' — ',1)[1]
  entry['notes'].append('Removed editorial description that gave away the graph-reading answer.')
 if code=='FA 034':stem='What is the slope of the line shown in the graph?'
 # Native choices describe all four graph options; the original figure also remains.
 assert stem and all(c['text'] for c in q['choices'])
 assets={'source_bank':'est-reviewed-banks-2026','source_code':code,'source_document':'EST_I_Math_Questions_by_Topic-2.pdf',
         'source_page':q['source_page'],'domain':q['domain'],'subtopic':q['subtopic']}
 assert len(images)<=1
 if images:assets.update(image=BASE+images[0],image_alt=f'Original diagram for {code}')
 topic=topic_for(q['domain'],q['subtopic'])
 questions.append(dict(id=identity('topic',code),track_id='est',topic=q['domain']+' · '+topic,
     difficulty='medium',type='mcq',stem=stem,choices=q['choices'],assets=assets,
     correct=review['answer'],explanation=review['explanation']))
 entry['status']='reviewed'
 if printed!=review['answer']:entry['notes'].append('Printed key corrected using independent algebra and the worked solution.')
 audit.append(entry)

for code,domain,subtopic,stem,options,correct,explanation in json.loads((OUT/'clean-reviewed.json').read_text()):
 record=cat['clean',code]
 assets={'source_bank':'est-reviewed-banks-2026','source_code':code,'source_document':'Math_Question_Bank_Ghoneem_Clean.pdf',
         'source_page':record['page'],'domain':domain,'subtopic':subtopic}
 if code=='GTC 014':
  assets['svg']='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 430 270" role="img" aria-label="Right triangle ABC, right angle at A, AB equals 3 and angle C equals 40 degrees"><path d="M65 40H365L65 235Z M65 60H85V40" fill="none" stroke="#233247" stroke-width="3"/><g fill="#233247" font-size="22"><text x="40" y="35">A</text><text x="40" y="260">B</text><text x="373" y="45">C</text><text x="32" y="143">3</text><text x="295" y="76">40°</text></g></svg>'
 questions.append(dict(id=identity('clean',code),track_id='est',topic=domain+' · '+topic_for(domain,subtopic),
     difficulty='medium',type='mcq' if options else 'grid_in',stem=stem,
     choices=[{'key':k,'text':t} for k,t in zip('ABCD',options)],assets=assets,correct=correct,explanation=explanation))
 audit.append({'source':'clean','code':code,'status':'reviewed','reviewed_answer':correct,
    'notes':['Visually transcribed the complete question, excluding neighboring fragments. Independently solved and checked by substitution, expansion, or a second relation.']})

assert len(questions)==271
assert len(set(q['id'] for q in questions))==len(questions)
assert all(q['correct'] and q['explanation'] for q in questions)
bydomain=defaultdict(list);bytopic=defaultdict(list)
for q in questions:
 bydomain[q['assets']['domain']].append(q);bytopic[q['topic']].append(q)
exams=[]
def assessment(code,title,qs,kind):
 ids=[q['id'] for q in qs];assert len(ids)==len(set(ids))
 exam=dict(id=identity('exam',code),track_id='est',title=title,duration_seconds=4500 if kind=='full_exam' else 90*len(ids),
    question_ids=ids,shuffle=False,review_policy='full_review',max_attempts=1,is_published=False,
    is_full_length=kind=='full_exam',assessment_type=kind,scoring_map=None,
    exam_set_code=None,module_number=None,module_count=None)
 exams.append(exam)
 # Both uploaded documents must contribute to each full paper.
 if kind=='full_exam':
  assert len(ids)==50
  assert Counter(q['assets']['domain'] for q in qs)==Counter(FA=15,DAP=15,AAF=15,GT=5)
  assert len(set(q['assets']['source_document'] for q in qs))==2

rng=random.Random(20260910)
for group in bydomain.values():rng.shuffle(group)
for n in range(5):
 paper=[]
 for domain,quota in [('FA',15),('DAP',15),('AAF',15),('GT',5)]:
  group=bydomain[domain];paper.extend(group[n*quota:(n+1)*quota])
 rng.shuffle(paper)
 assessment(f'full-{n+1}',f'EST Math 1 — Question Bank Practice {n+1:02}',paper,'full_exam')

for topic,qs in sorted(bytopic.items()):
 ordered=sorted(qs,key=lambda q:q['assets']['source_code'])
 assessment('lesson-'+topic,'EST — '+topic+' — Lesson exam',ordered,'lesson_exam')
 # A shorter selection, distributed through the lesson rather than its first rows.
 count=min(5,len(ordered));quiz=[ordered[i*len(ordered)//count] for i in range(count)]
 assessment('quiz-'+topic,'EST — '+topic+' — Quick quiz',quiz,'quiz')

selected={(a['source'],a['code']):a for a in audit}
for r in catalogue:
 reviewed=selected.get((r['source'],r['code']))
 r['review_status']=reviewed['status'] if reviewed else 'not_selected_for_scored_release'
 r['correct']=None if not reviewed or reviewed['status']=='excluded' else reviewed['reviewed_answer']
 r['explanation']=next((q['explanation'] for q in questions if q['assets']['source_code']==r['code'] and (q['assets']['source_document'].startswith('EST_'))==(r['source']=='topic')),None)

dump('catalogue.json',catalogue)
dump('review-audit.json',audit)
dump('reviewed-bank.json',{'questions':questions,'exams':exams})
dump('release-summary.json',{'questions':len(questions),'topic_pdf_questions':241,'clean_pdf_questions':30,
  'domains':dict(Counter(q['assets']['domain'] for q in questions)),
  'topics':{t:len(q) for t,q in sorted(bytopic.items())},'full_exams':5,
  'full_exam_questions':50,'full_exam_minutes':75,'domain_mix':{'FA':15,'DAP':15,'AAF':15,'GT':5},
  'lesson_exams':len(bytopic),'quizzes':len(bytopic),
  'excluded_topic_questions':[a['code'] for a in audit if a['status']=='excluded'],
  'unselected_clean_source_entries':669,
  'scope_note':'The clean PDF contains multi-question crops, fragments, duplicates and key pages. Its 699 source entries are not 699 unique validated questions. Thirty complete reviewed questions are included in this release.'})

# Remove the unreviewed source crops from public assets. Keep selected evidence in
# the private source tree; other temporary crops can be regenerated from PDFs.
scratch=Path('/workspace/scratch/861668d2e749/est-source-crops');scratch.mkdir(exist_ok=True)
evidence=OUT/'source-evidence';evidence.mkdir(exist_ok=True)
for p in (ROOT/'web/exams/est-banks-2026').glob('*.png'):
 code=p.stem.removeprefix('clean-').upper().replace('-',' ')
 if p.name.startswith('clean-') and ('clean',code) in selected:shutil.copy2(p,evidence/p.name)
 shutil.move(str(p),scratch/p.name)
print(json.dumps({'questions':len(questions),'domains':{d:len(v) for d,v in bydomain.items()},'exams':len(exams),'topics':len(bytopic)},indent=2))
