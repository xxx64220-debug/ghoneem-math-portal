"""Extract exact question artwork from the supplied PDF; never OCR/retype maths."""
import fitz
import json
import hashlib
import shutil
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'content/est-march-2026/source.pdf'
OUT = ROOT / 'web/exams/est-march-2026'
doc = fitz.open(SOURCE)
# Coordinates refer to the reviewed 1.3x page renders. Shared passages are
# repeated before each dependent question, including across a page break.
regions = {
 3: [(1,120,246),(2,250,380),(3,630,733),(4,735,861)],
 4: [(5,123,263),(6,265,407),(7,410,535),(8,540,642),(9,643,762)],
 5: [(10,271,378),(11,380,497),(12,500,625),(13,630,735),(14,738,853)],
 6: [(15,124,259),(16,260,572),(17,574,716),(18,718,918)],
 7: [(19,122,278),(20,282,395),(21,398,678),(22,700,807)],
 8: [(23,120,232),(24,306,448),(25,447,615),(26,617,824),(27,822,953)],
 9: [(28,122,225),(29,228,333),(30,337,465),(31,470,593),(32,596,702),(33,704,811)],
 10:[(34,118,271),(35,272,379),(36,379,487),(37,487,620),(38,620,781)],
 11:[(39,70,543),(40,549,674),(41,676,778)],
 12:[(42,407,510),(43,514,617),(44,623,728),(45,730,883)],
 13:[(46,118,242),(47,245,587),(48,587,711),(49,711,819),(50,819,937)],
}
shared = {**{n:(3,392,627) for n in [3,4,5]},
          **{n:(5,122,268) for n in [10,11]},
          **{n:(8,241,305) for n in [24,25]},
          **{n:(12,45,398) for n in [42,43]}}
topics = [
 'Ratios and proportions','Statistics: median','Rates and tables','Percentages','Percentages',
 'Probability','Permutations','Linear equations','Function operations','Probability',
 'Conditional probability','Percentages','Polynomial factors','Simple interest','Statistics: mean',
 'Circles and arc length','Arithmetic word problems','Radicals','Absolute value equations','Quadratic functions',
 'Systems of inequalities','Coordinate geometry: midpoint','Equations and inequalities','Polynomial coefficients','Polynomial coefficients',
 'Linear functions and tables','Ratios and proportions','Volume of spheres','Polynomial roots','Linear inequalities',
 'Percentages','Function operations','Linear equations','Systems of equations','Coordinate geometry: slope',
 'Units and rounding','Quadratic discriminant','Exponents','Perpendicular lines','Quadratic functions',
 'Absolute value expressions','Function graphs','Function inequalities','Complex numbers','Rearranging formulas',
 'Radicals','Triangle area','Coordinate geometry: distance','Polynomial remainder theorem','Linear inequalities']
manifest=[]
OUT.mkdir(parents=True,exist_ok=True)
for page,items in regions.items():
 for n,y0,y1 in items:
  parts=([shared[n]] if n in shared else [])+[(page,y0,y1)]
  clips=[(p,fitz.Rect(20/1.3,a/1.3,735/1.3,b/1.3)) for p,a,b in parts]
  composite=fitz.open()
  target=composite.new_page(width=715/1.3,height=sum(r.height for _,r in clips)+12*(len(clips)-1))
  y=0
  for p,r in clips:
   target.show_pdf_page(fitz.Rect(0,y,r.width,y+r.height),doc,p-1,clip=r)
   y+=r.height+12
  path=OUT/f'q{n:02}.png'
  target.get_pixmap(matrix=fitz.Matrix(2.6,2.6)).save(path)
  manifest.append({'number':n,'id':str(uuid.uuid5(uuid.NAMESPACE_URL,f'ghoneem:est-march-2026:q{n}')),
    'topic':topics[n-1],'source_page':page,'regions':parts,'image':f'/exams/est-march-2026/q{n:02}.png',
    'image_sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
assert [q['number'] for q in manifest]==list(range(1,51))
(ROOT/'content/est-march-2026/manifest.json').write_text(json.dumps({
 'title':'EST I Math — March 2026','duration_seconds':4500,'assessment_type':'full_exam',
 'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'questions':manifest},indent=2))
print(f'Extracted {len(manifest)} complete question images with shared passages.')

for i,name in enumerate(['instructions','reference']):
 doc[i].get_pixmap(matrix=fitz.Matrix(2,2)).save(OUT/f'{name}.png')
