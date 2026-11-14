"""Build the reviewed content-only release. This script never connects to a database."""
from pathlib import Path
import json, uuid, math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'content-releases/20261114_bank_review'
RELEASE = '20261114-bank-review'
load = lambda name: json.loads((OUT / (name + '.json')).read_text())
before = {q['id']: q for q in load('full_candidates') + load('full_repairs')}
hashes = {q['id']: q for name in ['unreleased', 'mset_reviewed', 'full_repairs'] for q in load(name)}
updates, additions = {}, []

def patch(qid, reason, **fields):
    q = before[qid]
    p = updates.setdefault(qid, dict(id=qid, row_hash=hashes[qid]['row_hash'], key_hash=hashes[qid]['key_hash'], fields={}, assets_merge={}, assets_remove=[], reasons=[]))
    p['reasons'].append(reason)
    p['fields'].update(fields)
    p['assets_merge'].update(bank_review_release=RELEASE, bank_review_date='2026-11-14')
    return p

for q in load('unreleased'):
    p = patch(q['id'], 'Answer independently checked against the complete statement and all options; required visuals inspected.')
    p['assets_merge'].update(verified_release=RELEASE, answer_review_status='independently_solved')

# Complete explanations replace links to absent worked-answer images.
solutions = {
 '08891f95-057c-59d1-9834-196b8872ba10': 'The lowest point on the scatterplot represents the least sleep, about 5.5 hours. Its age coordinate is about 39 years; the closest listed age is 40, choice B.',
 '44bddf08-7b19-5222-acb5-5eaa9d5789d7': 'The radius DE has squared length (4√10)² + (34 − 16)² = 160 + 324 = 484, so DE = DF = 22. DF is horizontal and the perpendicular height from E to DF is 18. The triangle area is ½ × 22 × 18 = 198 square units, choice A.',
 '8b79f97d-7d46-5542-be2b-5083826a7317': 'The radius is 12. Substituting (8,27) gives (8 − h)² + (27 − k)² = 144, so |27 − k| ≤ 12 and 15 ≤ k ≤ 39. Only 39 is listed in this interval. It works with h = 8, so the answer is C.',
 'ed76ef45-9030-5378-b804-4c4650a634ea': 'The original mean is (91 + 96 + 88 + 91 + 84)/5 = 90. Adding 100 makes the mean 550/6 ≈ 91.67, an increase. The sorted data become 84, 88, 91, 91, 96, 100; both the old median and new median are 91. Thus C is correct.',
 'f071a174-ffa8-5c12-b7d7-45d4c9dec57f': 'A sample mean of 7 minutes with margin of error 2 minutes gives the plausible interval 7 ± 2, or 5 to 9 minutes, for the population mean. It does not describe every individual wait or rule out all population means outside the interval. Therefore C is the appropriate conclusion.'
}
for qid, explanation in solutions.items():
    patch(qid, 'Replace answer-sheet reference with an independently worked explanation.', explanation=explanation)

def svg(body, label, width=520, height=300):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="100%" role="img" aria-label="{label}"><rect width="100%" height="100%" fill="white"/>{body}</svg>'

# Eight bank records used the same unrelated cover artwork. Six statements already
# contain their complete numerical givens. The remaining two are explicitly
# clarified instructor versions, with the original statement retained in metadata.
cover_ids = [q['id'] for q in load('full_repairs') if q['track_id'] == 'sat']
for qid in cover_ids:
    p = patch(qid, 'Remove unrelated cover artwork; preserve the answer and all attempt records.')
    p['assets_remove'] += ['figure', 'figure_caption']
    p['assets_merge'].update(figure_required=False, display_repair='Unrelated cover image removed after visual inspection.')

qid = 'ed362c08-1a82-5b56-be44-044737f550e7'
patch(qid, 'The complete linear model is given in text.', stem='A linear model of copper resistivity, in nanoohm-meters, against temperature, in kelvins, passes through approximately (0,0) and (1000,60). Which rate statement is correct?')

qid = '38b3ea7c-1a64-5d12-8944-dedd2448b7c9'
p = patch(qid, 'Explicit instructor clarification supplies the right angle and angle correspondence missing from the unrelated image.', stem='In right triangle RST, angle T is 90° and tan R = 140/171. An acute angle X in a similar right triangle is equal to angle S. What is sin X?', explanation='Take ST = 140 and RT = 171. The hypotenuse is √(140² + 171²) = 221. Since X = S, sin X = RT/RS = 171/221, choice C.')
p['assets_merge'].update(content_origin='instructor_adaptation', adaptation_reason=p['reasons'][-1], source_original_stem=before[qid]['stem'])

qid = '2574795c-0842-5799-a7a6-9f318be55de6'
p = patch(qid, 'Explicit instructor diagram defines the two exterior angles and the requested angle; it is not claimed to be a recovered source image.', stem='Lines AB and CD are parallel, and segments AD and BC intersect at E. Ray AU extends AB to the left, and ray CV extends CD to the left. If ∠UAE = 115° and ∠VCE = 118°, what is the measure of ∠BED, in degrees?', explanation='The angle between AD and a rightward horizontal ray is 180° − 115° = 65°. The angle between BC and a rightward horizontal ray is 180° − 118° = 62°. These two angles make ∠BED, so its measure is 65° + 62° = 127°, choice C.')
# Coordinate slopes follow the stated 65° and 62° angles exactly.
cx, cy, dy = 300, 150, 95
A=(cx-dy/math.tan(math.radians(65)),cy-dy); B=(cx+dy/math.tan(math.radians(62)),cy-dy)
C=(cx-dy/math.tan(math.radians(62)),cy+dy); D=(cx+dy/math.tan(math.radians(65)),cy+dy)
line=lambda a,b:f'<path d="M{a[0]:.3f} {a[1]:.3f}L{b[0]:.3f} {b[1]:.3f}" fill="none" stroke="#173a55" stroke-width="2.5"/>'
label=lambda x,y,t:f'<text x="{x:.3f}" y="{y:.3f}" font-size="17" fill="#173a55">{t}</text>'
body=line((80,55),(460,55))+line((80,245),(460,245))+line(A,D)+line(C,B)
for name,pt,dx,dy2 in [('A',A,0,-12),('B',B,0,-12),('C',C,0,25),('D',D,0,25),('E',(cx,cy),-24,5)]: body+=label(pt[0]+dx,pt[1]+dy2,name)
body+=label(82,43,'U')+label(82,272,'V')+label(A[0]-70,91,'115°')+label(C[0]-65,218,'118°')+label(cx+17,cy+6,'x°')+label(385,159,'AB ∥ CD')
p['assets_merge'].update(svg=svg(body,'Parallel lines AB and CD, crossing segments AD and BC, and labeled exterior angles'),figure_required=True,content_origin='instructor_adaptation',adaptation_reason=p['reasons'][-1],source_original_stem=before[qid]['stem'])

qid = 'df2132af-840a-501e-9268-3a64a7d75791'
p = patch(qid, 'Explicit instructor clarification adds the omitted 90° central angle. The existing accepted answer D is unchanged.', stem='A circle has center O and radius 1/6. The central angle AOC is 90°, and B lies on the minor arc from A to C. What is the length of arc ABC?', choices=[{'key':k,'text':v} for k,v in zip('ABCD',[r'$\frac{\pi}{2}$',r'$\frac{\pi}{4}$',r'$\frac{\pi}{8}$',r'$\frac{\pi}{12}$'])], explanation='The minor arc is one quarter of the circumference: (90/360) × 2π × (1/6) = π/12, choice D. This clarified instructor version explicitly states the right angle omitted from the original source.')
p['assets_remove'] += ['figure']
p['assets_merge'].update(content_origin='instructor_adaptation',adaptation_reason=p['reasons'][-1],source_original_stem=before[qid]['stem'],figure_required=False)

def adapt(source, topic, stem, choices, answer, solution, reason, difficulty='medium', other_sources=()):
    sources=[source,*other_sources]
    qid=str(uuid.uuid5(uuid.NAMESPACE_URL, 'ghoneem:'+RELEASE+':'+source))
    q=dict(id=qid,track_id='act2',topic=topic,difficulty=difficulty,type='mcq' if choices else 'grid_in',stem=stem,choices=[{'key':k,'text':v} for k,v in zip('ABCD',choices)],correct=answer,explanation=solution,assets=dict(source='Ghoneem Math — reviewed instructor adaptation',source_ids_adapted=sources,content_origin='instructor_adaptation',adaptation_reason=reason,curriculum_lesson=topic,lesson_subtopic=topic,verified_release=RELEASE,answer_review_status='independently_solved',figure_required=False,bank_review_date='2026-11-14'))
    additions.append(q)
    for old in sources:
        p=patch(old,'Retain the defective source and link its independently checked adaptation.')
        p['assets_merge'].update(replacement_question_id=qid,replacement_review_release=RELEASE,replacement_review_note=reason)

adapt('1115c92c-eca5-5c40-b42f-f782066e4eff','Trigonometry','A 20-meter ladder rests against a vertical wall on level ground. The ladder makes an angle of 65° with the ground. How high up the wall does it reach, in meters? Round to the nearest hundredth.',[],'18.13','The ladder is the hypotenuse. Its vertical height is 20 sin 65° ≈ 18.12616 meters, which rounds to 18.13 meters.','Add explicit nearest-hundredth precision and the right-triangle setting.')
adapt('2da9d842-d0a0-5b81-a3e7-831e75a4f515','Logarithms and exponentials',r'For real x, solve $\log_3(x-1)+\log_3(x+1)=2$.',[r'$-\sqrt{10}$',r'$\sqrt{10}$','10','3'],'B',r'The domain requires x > 1. Combining logarithms gives $\log_3(x^2-1)=2$, so x² − 1 = 9 and x = ±√10. Only √10 satisfies the domain.','Provide instructor-authored exact-answer choices so no unstated rounding is required.')
adapt('98cb24bf-e675-5d2e-a4c0-bd834cbbc0f2','Trigonometry','In triangle ABC, sides a = 7 and b = 10 are opposite angles A and B. The included angle C is 60°. What is the exact length of side c, opposite C?',[r'$\sqrt{79}$',r'$\sqrt{149}$','17','3'],'A','By the cosine rule, c² = 7² + 10² − 2(7)(10) cos 60° = 149 − 70 = 79. Since c is a length, c = √79.','State the side convention and add exact-answer choices.')
adapt('a66e7923-397b-5cd5-995c-04205246199d','Circles','A circle has a diameter of 11 inches. What is its exact circumference?',[r'$11\pi$ inches',r'$22\pi$ inches',r'$121\pi$ inches',r'$\frac{11\pi}{2}$ inches'],'A','Circumference is π times diameter, so C = 11π inches.','Supply exact-answer choices for an unsupported irrational numeric response.','easy')
adapt('d0ffb261-513f-551b-88c4-9b6845e98178','Circles','A circle has a diameter of 17 units. What is its exact area?',[r'$17\pi$',r'$\frac{289\pi}{4}$',r'$289\pi$',r'$\frac{17\pi}{2}$'],'B','The radius is 17/2. Area = π(17/2)² = 289π/4 square units.','Supply exact-answer choices instead of assuming an unstated decimal precision.','easy')
adapt('9b4f5a2d-27d7-5210-922a-31e2556e7130','Quadratics and polynomials','Which is the positive solution of 6x² − 7x − 3 = 0?',['−1/3','3/2','−3/2','1/3'],'B','Factor as (3x + 1)(2x − 3) = 0. The roots are −1/3 and 3/2; only 3/2 is positive.','Add “positive” to remove the source’s two-correct-choice ambiguity.')
adapt('9b45a010-891a-5c72-aeb0-4346e6f82c3f','Statistics and data analysis','Ted’s first five scores were 70, 70, 80, 70, and 80. Two more scores, 90 and 95, are added to the same data set. How do the mean and median change?',['Mean increases by 5; median stays the same','Mean increases by 37/7; median increases by 10','Mean increases by 10; median increases by 37/7','Mean increases by 37/7; median stays the same'],'B','The original sum is 370, so the mean is 74 and median 70. The new sum is 555, so the mean is 555/7 and its increase is 555/7 − 74 = 37/7. The sorted seven scores have median 80, an increase of 10.','Replace defective options with instructor-authored choices, including the exact changes.')
adapt('93b5da55-a8b7-58f0-a38c-4e4fc3d1fcb1','Statistics and data analysis','The data set is 75, 70, 80, 70, 80, 90, 95, 70, 70, 75, 80, 80, 90, 95. Which statement correctly compares its mean and median?',['The mean is less than the median','The mean equals the median','The mean is greater than the median','The mean and median cannot be determined'],'B','The sum is 1120 and there are 14 values, so the mean is 80. The seventh and eighth sorted values are both 80, so the median is also 80.','Convert the unsupported descriptive response to a single multiple-choice comparison.')
adapt('a7e0c938-c48b-50d8-88b3-8388c07f0560','Circles','A car tire of radius 14 inches rolls without slipping for 1 mile. How many rotations does it make, rounded to the nearest whole number? Use 1 mile = 5,280 feet.',[],'720','One mile is 5,280 × 12 = 63,360 inches. One rotation covers 2π(14) = 28π inches. Thus the number of rotations is 63,360/(28π) ≈ 720.288, which rounds to 720.','Add explicit whole-number rounding; do not silently substitute π = 22/7.')
p=patch('d155cd26-9e65-58a5-ac5b-26a21eba28e2','Reuse the existing independently checked cylinder version instead of adding a near-duplicate.')
p['assets_merge'].update(replacement_question_id='015afa55-5485-5f8e-8925-5d6abe52776f',replacement_review_release=RELEASE,replacement_review_note='Existing live version explicitly specifies π = 22/7, giving radius 5 exactly. Reuse that version rather than creating a second rounding adaptation.')

adapt('e79575f2-6d3f-55d4-a583-f6b42f9f949e','Complex numbers','Write z = 4(cos 60° + i sin 60°) in rectangular form.',[r'$2+2\sqrt3\,i$',r'$2\sqrt3+2i$',r'$4+i$',r'$2-2\sqrt3\,i$'],'A','Using cos 60° = 1/2 and sin 60° = √3/2 gives z = 2 + 2√3 i.','Explicitly specify degrees; the original omitted the angle unit.')
adapt('fddc7217-091d-5eb2-9649-52643c66cac0','Angles and polygons','What is the measure, in degrees, of each interior angle of a regular octagon?',['135','180','160','45'],'A','The interior-angle sum is (8 − 2) × 180° = 1080°. In a regular octagon all eight angles are equal, so each is 1080°/8 = 135°.','Add the necessary regularity condition omitted by the source.','easy')
adapt('b6763c00-7ba0-5573-a0ce-4434dd00d24c','Ratios, percentages and unit conversion','All of the following numbers are greater than 1/2 EXCEPT:',[r'$\frac{101}{200}$',r'$\frac{17}{33}$',r'$\frac7{12}$',r'$\frac25$'],'D','101/200 > 1/2 because 202 > 200; 17/33 > 1/2 because 34 > 33; 7/12 > 1/2 because 14 > 12. But 2/5 = 0.4 < 1/2. Thus only D is an exception.','Replace 600/1000 with the explicitly instructor-authored 2/5 option. Both defective copies link to this single adaptation.','easy',other_sources=['c0edf793-69ae-51f1-9c63-00444e743f84'])

manifest=dict(release=RELEASE,updates=list(updates.values()),additions=additions)
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(f'{len(updates)} guarded updates; {len(additions)} reviewed additions')
