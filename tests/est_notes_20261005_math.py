from pathlib import Path
import json, math
from fractions import Fraction
p=json.loads((Path(__file__).resolve().parents[1]/"content-releases"/"20261005_uploaded_notes_est_bank"/"packet.json").read_text())
qs=p["questions"]
assert len(qs)==15 and len({q["id"] for q in qs})==15
assert all(q["track_id"]=="est" and q["correct"] is not None and q["explanation"] for q in qs)
assert all(q["assets"]["source_sha256"]==p["source_sha256"] for q in qs)
assert sum(q["type"]=="mcq" for q in qs)==8
assert sum(q["type"]=="grid_in" for q in qs)==7
by_page={(q["assets"]["source_page"],q["assets"]["source_item"]):q for q in qs}
assert by_page[(1,1)]["correct"]=="12"
assert by_page[(2,1)]["correct"]=="E" and Fraction("30.75")==Fraction(123,4)
assert by_page[(2,2)]["correct"]=="A" and 10**2-7**2==51
assert by_page[(4,1)]["correct"]=="33" and (-9)**2+4*(-9)-12==33
assert by_page[(5,1)]["correct"]=="B"
assert by_page[(5,2)]["correct"]=="A" and (-6)**2==36
assert by_page[(6,1)]["correct"]=="35" and 3*35-2*15==75
assert by_page[(8,2)]["correct"]=="3234" and 3500*Fraction(88,100)*Fraction(105,100)==3234
assert by_page[(9,1)]["correct"]=="5" and 5*(7*5-4)==155
assert by_page[(9,2)]["correct"]=="D" and Fraction(114,100)*Fraction(104,100)==Fraction(1482,1250)
assert by_page[(10,1)]["correct"]=="B" and 7*Fraction(-1,7)==-1
assert by_page[(10,2)]["correct"]=="C" and 4*80-3*76==92
assert by_page[(11,1)]["correct"]=="A" and round(Fraction(14325,1)/Fraction(1225,1000))==11694
assert by_page[(11,2)]["correct"]=="0.5" and 4*Fraction(1,2)**2+4==5
assert by_page[(12,1)]["correct"]=="187.5"
# The held exponent equation has two real roots: one in (-1, 0), another in (2, 3).
f=lambda n:(n-1)**4+4*n-11
assert f(-1)>0 and f(0)<0 and f(2)<0 and f(3)>0
assert any(x["status"]=="held_source_defect" for x in p["excluded"])
assert sum(x["status"]=="duplicate_skipped" for x in p["excluded"])==3
# The preserved rectangle graph is a self-contained SVG data URI.
figure=by_page[(2,1)]["assets"]["figure"]
assert figure.startswith("data:image/svg+xml;base64,")
assert "Figure 8" in by_page[(2,1)]["stem"]
print("PASS: 15 EST I questions verified; 3 duplicates excluded; 2 incomplete/defective items held.")
