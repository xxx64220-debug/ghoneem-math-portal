"""Offline mathematical and coverage regressions for the 356-record June review."""
import itertools
import json
import math
from fractions import Fraction as F
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'content-releases/20260929_june_remaining_review'
records=json.loads((D/'reviewed-records.json').read_text())
ledger=json.loads((D/'review-ledger.json').read_text())
repairs=json.loads((D/'repairs.json').read_text())
prior=json.loads((ROOT/'content-releases/20260929_revision_contamination_review/repairs.json').read_text())
assert len({r['id'] for r in records})==len(records)==356
assert {r['id'] for r in ledger}=={r['id'] for r in records}
assert not ({r['id'] for r in prior}&{r['id'] for r in records})
assert len(prior)+len(records)==484
assert len({(r['source_page'],r['source_question']) for r in ledger})==187
assert len(repairs)==263 and sum(r['status']=='held' for r in ledger)==16
after={r['id']:r for r in records}
for p in repairs:
    old=after[p['id']]
    assert {k:old[k] for k in p['before']}==p['before']
    assert old['track_id']==p['track_id']
    assert old['assets_md5']==p['before_assets_md5']
    if old['release_hold_reason']:
        assert p['asset_patch'].get('release_hold_reason',old['release_hold_reason'])==old['release_hold_reason']
    after[p['id']]={**old,**p['after']}
    if p['status']=='held':
        assert p['after']['correct']['void'] is True and p['asset_patch']['release_hold_reason']
    else: assert p['after']['correct'] in [c['key'] for c in p['after']['choices']]
for r in after.values():
    assert r['explanation'] and not r['explanation'].startswith(('Verified answer key;', 'Answer key transcribed'))

def group(page,q):return [r for r in after.values() if (r['source_page'],r['source_question'])==(page,q)]
def held(page,q):assert all(isinstance(r['correct'],dict) and r['correct'].get('void') for r in group(page,q))

# Multiple valid options: never blindly trust a single printed letter.
assert all(abs(3*x+7)<4 for x in [F(-3),F(-2),F(-3,2)])
assert all(abs(-4*x+1)>-5 for x in range(-100,101))
assert sum(r['correct']==['B','D'] for r in group(3,5))==1
assert sum(isinstance(r['correct'],dict) for r in group(3,5))==1
polys=[lambda x:x**3-x*x-6*x,lambda x:x**3+x*x-6*x,lambda x:x**3-5*x*x+6*x,lambda x:x**3-7*x-6]
assert [i for i,f in enumerate(polys) if f(3)==f(-2)==0]==[0,3]
held(16,76)

# Source arithmetic conflicts are held, not rounded/truncated to a convenient key.
balance=F(6000)*F(105,100)**8
assert round(float(balance),2)==8864.73
assert all(abs(6000*(1+r/100)**8-8950.95)>0.01 for r in [1,3,5,7])
held(20,94)
average=(30*F('15.8')+20*F('16.2')+10*F('17.2')-60)/57
assert average==F(910,57) and round(float(average),1)==16.0
assert average not in map(F,['50.7','15.9','15.1','48.2'])
held(22,106)
assert {3*175-(510-leaving) for leaving in [160,170,180]}=={175,185,195}
held(36,6)
assert F(9)*26/F('1.2')==195
held(24,117) # Proportional arithmetic does not validate an impossible unit equivalence.

# Marginal probabilities alone do not justify multiplying repeated trials.
assert F(3,10)**3==F(27,1000) and F(3,10)!=F(27,1000)
held(38,19);held(38,18)
assert sum((a*b)%2==0 for a,b in itertools.product(range(1,5),range(1,4)))==8

# Flattened powers produce a different problem, despite the old plausible-looking key.
assert 3**(3+2)-3**3==216
for r in group(48,6):assert '3^{x+2}' in r['stem']
for r in group(49,7):assert '2^a' in r['stem'] and '3^b' in r['stem']
assert math.isclose(math.log(3,2)*math.log(8,3),3)

# Shared context must survive standalone selection in either import.
for r in group(12,56):assert '128' in r['stem'] and '320' in r['stem']
assert -16*10**2+128*10+320==0
for r in group(23,115):assert all(n in r['stem'] for n in ['134,400','85,440','239,400','117,000'])
assert sum([134400,85440,239400,117000])*F(11,100)==F('63386.4')
for r in group(23,116):assert '239,400' in r['stem'] and '19' in r['stem']
assert F(239400,19*12)*F(4,5)==840
for r in group(50,16):assert 'x² − 6x + 4' in r['stem']
assert 6**2-2*4==28
graph_repairs=[r for r in repairs if 'figure' in r['asset_patch']]
assert len(graph_repairs)==1 and graph_repairs[0]['id'].startswith('ded3e6cc')
assert graph_repairs[0]['asset_patch']['figure'].startswith('data:image/')

# Independent additional exact checks of boundary-sensitive calculations.
assert [x for x in range(-10,10) if math.sqrt(x+13)==x+1]==[3]
assert len([c for c in itertools.combinations(range(10),4) if sum(i>=7 for i in c)<=2])==203
valid=[(a,b,12,13,13) for a in range(1,13) for b in range(a,13) if a+b==12 and b!=12 and a!=b]
assert max(v[1] for v in valid)==11
assert 1/(F(1,2)-F(1,6)-F(1,9))==F(9,2)
print('PASS: all 356 records accounted for; 187 worked solutions; ambiguity, source arithmetic, superscripts, shared context and hold regressions.')
