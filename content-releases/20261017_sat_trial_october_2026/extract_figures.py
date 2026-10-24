import runpy,pathlib,json,hashlib,uuid,base64,io,re
from PIL import Image,ImageOps,ImageDraw
root=pathlib.Path(__file__).resolve().parent
data=runpy.run_path(str(root/'build.py'));rows=data['rows']
sourcefiles={1:'bluebookycom_261016_135811.pdf',2:'bluebookycom2_261016_135804.pdf'}
sources=[{'file':f,'sha256':hashlib.sha256(pathlib.Path('upload',f).read_bytes()).hexdigest(),'pages':69 if p==1 else 62} for p,f in sourcefiles.items()]
sources.append({'file':'bluebookycom2-answers_261016_135808.pdf','sha256':hashlib.sha256(pathlib.Path('upload/bluebookycom2-answers_261016_135808.pdf').read_bytes()).hexdigest(),'pages':5})
refs={r['ref']:r for r in rows};out=[];crops=[]
(root/'figures').mkdir(exist_ok=True)
for r in rows:
 if 'duplicate_of' in r:continue
 occurrences=[x for x in rows if x['ref']==r['ref'] or x.get('duplicate_of')==r['ref']]
 assets=dict(source='SAT Trial 2026 October',source_document=f'SAT Trial 2026 October — Paper {r["paper"]}',source_file=sourcefiles[r['paper']],source_code='SAT-OCT26-'+r['ref'],source_question_id='SAT-OCT26-'+r['ref'],source_page=r['page'],source_module=r['module'],source_number=r['number'],source_sha256=next(s['sha256'] for s in sources if s['file']==sourcefiles[r['paper']]),source_occurrences=[{'code':'SAT-OCT26-'+x['ref'],'file':sourcefiles[x['paper']],'page':x['page'],'module':x['module'],'question':x['number']} for x in occurrences],paper='SAT Trial 2026 October',practice_collection='sat-trial-2026-october',verified_release='20261017-sat-trial-october-2026',answer_review_status='independently_solved',curriculum_lesson=r['topic'],lesson_subtopic=r['subtopic'],lesson_taxonomy_version='20260929',content_origin='user_supplied_trial',source_fidelity='Mathematical givens and options visually checked. Reflowed searchable text; redundant publisher tags omitted. Original diagrams extracted without answer lines.',difficulty_basis='Source module label; baseline assigned medium. Not calibrated from student performance.')
 if r['figure_crop']:
  im=Image.open(f'tmp/pdfs/pages/p{r["paper"]}-{r["page"]:02}.png')
  # Coordinates recorded against the 1334 x 1889 display, then scaled to actual source raster.
  rect=tuple(round(x*(im.width/1334 if i%2==0 else im.height/1889)) for i,x in enumerate(r['figure_crop']))
  crop=im.crop(rect).convert('L');bio=io.BytesIO();crop.save(bio,format='PNG',optimize=True)
  b=bio.getvalue();(root/'figures'/f'{r["ref"]}.png').write_bytes(b)
  assets.update(figure='data:image/png;base64,'+base64.b64encode(b).decode(),figure_required=True,figure_caption=f'Original diagram for SAT Trial 2026 October, Paper {r["paper"]}, {r["module"]}, question {r["number"]}.',figure_sha256=hashlib.sha256(b).hexdigest())
  tile=Image.new('RGB',(350,390),'white');crop.thumbnail((330,355));tile.paste(crop,(10,25));ImageDraw.Draw(tile).text((10,5),r['ref'],fill='red');crops.append(tile)
 choices=[] if r['choices'] is None else [{'key':chr(65+i),'text':c} for i,c in enumerate(r['choices'])]
 out.append(dict(id=str(uuid.uuid5(uuid.NAMESPACE_DNS,'ghoneem:20261017-sat-trial-october-2026:'+r['ref'])),track_id='sat',topic=r['topic'],difficulty={'M1':'medium','M2E':'easy','M2H':'hard'}[r['module']],type='mcq' if choices else 'grid_in',stem=r['stem'],choices=choices,assets=assets,correct=r['correct'],explanation=r['explanation']))
for start in range(0,len(crops),12):
 canvas=Image.new('RGB',(1400,390*((len(crops[start:start+12])+3)//4)),'#bbb')
 for i,t in enumerate(crops[start:start+12]):canvas.paste(t,((i%4)*350,(i//4)*390))
 canvas.save(f'tmp/pdfs/figure-contact-{start//12}.jpg')
notes=[{'ref':'P2-M1-18','printed':'B 1/122','verified':'B, 1/√2'},{'ref':'P2-M2E-03','printed':'B 2/552','verified':'B, 2/5'},{'ref':'P2-M2E-04','also':'P2-M2H-09','printed':'D (0,217)','verified':'D, (0,2/17)'},{'ref':'P2-M2H-08','printed':'B 1/1991','verified':'B, 1/9'}]
packet=dict(release='20261017-sat-trial-october-2026',label='SAT Trial 2026 October',source_occurrences=142,unique_questions=len(out),figures=len(crops),sources=sources,questions=out)
(root/'review.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2)+'\n')
(root/'transcription.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
(root/'source-key-corrections.json').write_text(json.dumps(notes,ensure_ascii=False,indent=2)+'\n')
print({'questions':len(out),'figures':len(crops),'grid_in':sum(q['type']=='grid_in' for q in out),'review_bytes':(root/'review.json').stat().st_size})
