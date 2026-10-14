"""Offline checks for the June-revision source repairs; no database connection."""
import itertools
import json
import math
import re
from fractions import Fraction as F
from pathlib import Path

root = Path(__file__).resolve().parents[1]
repairs = json.loads((root / 'content-releases/20260929_revision_contamination_review/repairs.json').read_text())
by_id = {r['id']: r for r in repairs}
assert len(by_id) == len(repairs) == 128
assert sum(bool(r['hold']) for r in repairs) == 2
for r in repairs:
    a = r['after']
    assert not re.search(r'Abdelrahman|Ghoneem|01116004434|SECTION|KEY IDEAS|STRATEGY NOTES', a['stem'] + json.dumps(a['choices']))
    assert len({c['key'] for c in a['choices']}) == len(a['choices'])
    assert len({c['text'] for c in a['choices']}) == len(a['choices'])
    assert a['explanation'].strip() and 'Verified answer key; source and release checks completed.' not in a['explanation']
    if r['hold']:
        assert a['correct']['void'] is True
    else:
        assert sum(c['key'] == a['correct'] for c in a['choices']) == 1
        assert not re.search(r'\bQ\d+\.|[A-E]\)', json.dumps(a['choices']))

def answer(id):
    a = by_id[id]['after']
    return next(c['text'] for c in a['choices'] if c['key'] == a['correct'])

# Enumerate outcomes independently rather than trusting the source answer key.
cards = [1]*4 + [2]*3 + [3]*5
pairs = list(itertools.combinations(range(len(cards)), 2))
prob = F(sum(cards[a] == cards[b] for a,b in pairs), len(pairs))
assert prob == F(answer('18dd77bd-17c8-c134-c2ca-edb204aae5ae')) == F(19,66)
assert prob != F('0.3')
arrangements = set(itertools.permutations('SELECTS'))
good = sum('EE' in ''.join(a) and 'SS' not in ''.join(a) for a in arrangements)
assert F(good,len(arrangements)) == F(answer('63a6ba9c-9de2-0909-dab0-856fb01575cb'))
assert len(set(itertools.permutations('ALGEBRA'))) == int(answer('294f440e-ac6b-188f-238f-ea030a228bb1'))
assert sum(a[0]=='E' for a in set(itertools.permutations('CHEESE'))) == int(answer('ab17bd43-f3bc-047d-b26a-6810c8251524'))
dice=list(itertools.product(range(1,7),repeat=2))
assert F(sum(math.isqrt(a*b)**2==a*b for a,b in dice),36) == F(answer('8f630bcb-bc58-36fb-3ae5-9dbdedc3e807'))
assert F(sum(a+b==9 for a,b in dice),36) == F(answer('322b2be2-dff2-03b6-a5e9-0a59dc34beaf'))
assert len(list(itertools.combinations(range(5),2))) * len(list(itertools.combinations(range(4),2))) == int(answer('3ef3f0cf-2ff4-cbd3-61d1-8e4ea0e0a94f'))

# The coefficient problem really has two branches. Neither may be silently lost.
values=set()
for a,b,c in [(F(8),F(0),F(0)),(F(8),F(-1,4),F(-1))]:
    for x in map(F,[-3,0,1,5]):
        assert (2*a-14)*x*x+5*b-c*x == 2*x*x-(4*x+5*c)*b
    values.add(a+8*b+c)
assert values == {5,8}

# Restore actual powers, not flattened text, and retain the negative real branch.
for id in ['52bd4551-0216-e07f-1745-9960a562caae','5726788a-a411-9c04-1e8b-ab8b040cf93c']:
    assert r'9^x + 9^x + 9^x = 3^{40}' in by_id[id]['after']['stem']
    assert 2*F(answer(id))+1 == 40
for id in ['ff99e36e-2e40-86ef-e2ce-80a49bdc0e30','08503895-cfe1-512e-e879-924a96779642']:
    a=by_id[id]['after']
    assert 'possible real value' in a['stem'] and '±64' in a['explanation']
    assert int(answer(id))==4**3

# Exact checks for repaired context and representative calculations.
assert 1-F(3,4)*F(5,7) == F(answer('09f5f5de-1382-1c09-9ad9-9a1a2b849405'))
assert F(30*F(4,5)+24*F(1,2),54) == F(answer('890e9b42-5a30-01d2-7884-6799c5bbef66'))
assert F(2,3) == F(answer('2281d7a4-9745-89ec-1fee-a5aa6dd8ee46'))
assert 100*(F(5,4)**2-1) == F(answer('ff6016b5-0fa9-b367-eda2-804e4453cdc9').rstrip('%'))
assert F(21)/(F(5,8)*300) == F(answer('d3939d54-d783-1d96-be8e-6e01e24f0b68'))
assert 9*(F(sum([2,3,7,7,9,11,12,13,15]),9)+7+9) == int(answer('250db919-c2b9-abed-c43d-67c0fe6377bd'))
assert round(math.degrees(math.asin(320/(40*(100/2-40)))),2) == float(answer('20d50309-e05b-c381-6129-b801c878d4be'))
print('PASS: 128 repair records; exact probability, combinatorics, ambiguity, exponent, and shared-context checks.')
