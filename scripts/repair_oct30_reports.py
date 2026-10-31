"""Reproducible, source-traceable figure and wording repairs; never contacts DB."""
import copy, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'security-releases/20261030-portal-followup'
before = json.loads((OUT / 'question-content-before.json').read_text())
def text(x, y, value, size=14, anchor='middle'):
    return f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}" fill="#18283f">{value}</text>'
def line(x1,y1,x2,y2,color='#d9dee5'):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1"/>'
def svg(body,label,h=300):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 {h}" role="img" aria-label="{label}"><rect width="400" height="{h}" fill="white"/>'+''.join(body)+'</svg>'
snow=[]
snow.append(text(200,19,'Annual snowfall (inches)',16))
for v in range(0,61,10):
    y=230-v*3
    snow += [line(48,y,380,y),text(39,y+5,v,14,'end')]
snow += [line(48,50,48,230,'#18283f'),line(48,230,380,230,'#18283f')]
values=[40,12,13,13,10,5,7,56,12,2,3,32,18]
points=[(58+i*26,230-v*3) for i,v in enumerate(values)]
snow.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in points)+'" fill="none" stroke="#18283f" stroke-width="2"/>')
for i,(x,y) in enumerate(points):
    snow.append(f'<circle cx="{x}" cy="{y}" r="3" fill="#18283f"/>')
    if i%2==0:snow.append(text(x,253,2003+i))
snow += [text(200,280,'Year',15),text(66,98,'(2003, 40)',14,'start'),text(130,152,'(2007, 10)',14,'start')]
snow_svg=svg(snow,'Washington DC annual snowfall, 2003 to 2015; 2003: 40 inches; 2007: 10 inches')
bars=[]
bars.append(text(200,19,'Cases by age group',16))
for value in range(0,3001,500):
    x=70+value/10
    bars += [line(x,40,x,256),text(x,276,value,13)]
# Approximate widths measured from the source raster, not recovered exact data.
counts=[410,1000,2875,2350,1725,1375,800,430,215]
labels=['0–10','10–20','20–30','30–40','40–50','50–60','60–70','70–80','80+']
for i,(v,label) in enumerate(zip(counts,labels)):
    y=40+i*24
    bars += [text(62,y+16,label,14,'end'),f'<rect x="70" y="{y}" width="{v/10}" height="23" fill="#506780"/>']
bars += [text(220,298,'Number of cases',15),text(200,323,'Approximate counts redrawn from the source.',12),text(200,341,'Age groups are shown on the left.',12)]
hist_svg=svg(bars,'Approximate histogram of cases by age group, redrawn from source PDF page 164',355)
(OUT/'snowfall.svg').write_text(snow_svg)
(OUT/'histogram.svg').write_text(hist_svg)
after=[]
for original in before:
    q=copy.deepcopy(original)
    if q['id']=='a9c9dcc4-509f-445b-9cb8-8658dc4551ac':
        q['assets'].pop('figspec',None);q['assets']['svg']=snow_svg
        q['assets']['figure_review']={'date':'2026-10-30','method':'Vector redraw of existing plotted values with readable year labels; labelled comparison values preserved.'}
    elif q['id']=='2ab2712a-3d29-54e5-ace7-8911594c715f':
        q['assets'].pop('figure',None);q['assets']['svg']=hist_svg
        q['assets']['figure_review']={'date':'2026-10-30','method':'Approximate bar proportions redrawn from original PDF page 164, PSD 025 Q16; original scan has no exact count labels. Approximation visibly labelled.','source_library_id':'libfile_0600c921942c8191b1b31d6472db5544'}
    elif q['id']=='e773194a-5f49-6be4-2600-4c9790f93f05':
        q['choices'][3]['text']='It increased by about 2.56%'
        q['explanation']='The reduced mass is 120 × 0.90 = 108 g. The old price per gram is 3.25/120 = 13/480 dollar; the new price is 3/108 = 1/36 dollar. The increase is 1/1440 dollar per gram. Relative to the old unit price, this is (1/1440)/(13/480) × 100 = 100/39%, approximately 2.56%. Answer D.'
        q['assets']['wording_review']='2026-10-30: Confirmed 108 g and replaced vague option D with the independently calculated percentage increase; key unchanged.'
    elif q['id']=='d29b13cd-c9c1-5285-2c63-6cea6a4bf68c':
        q['topic']='Linear functions and slope';q['assets']['curriculum_lesson']=q['topic'];q['assets']['lesson_subtopic']='Linear word problems'
        q['assets']['lesson_taxonomy_version']='20261030'
        q['explanation']='The initial water level is 34 feet and it decreases by 0.5 foot each day, so w = 34 − 0.5d. To find when it reaches 26 feet, solve 26 = 34 − 0.5d: 0.5d = 8, hence d = 16 days. This is a linear function with intercept 34 and slope −0.5.'
    else:continue
    after.append(q)
(OUT/'question-content-after.json').write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n')
print('Prepared four question repairs; all answer keys preserved.')
