"""Offline integrity checks for the second additive SAT and EST II revision release."""

from collections import Counter, defaultdict
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content-releases/20260930_est2_sat_revision_ideas"

manifest = json.loads((OUT / "manifest.json").read_text())
fingerprints = json.loads((OUT / "fingerprints.json").read_text())
audit = json.loads((OUT / "audit.json").read_text())
sql = (OUT / "apply.sql").read_text()

assert len(manifest) == 80 == len(fingerprints)
assert Counter(row["track"] for row in manifest) == {"sat": 40, "est2": 40}
assert len({row["id"] for row in manifest}) == 80
assert len({(row["track"], row["lesson"], row["idea"]) for row in manifest}) == 80
assert set(fingerprints) == {row["id"] for row in manifest}
assert all(re.fullmatch(r"[0-9a-f]{32}", value) for value in fingerprints.values())

lessons = defaultdict(Counter)
for row in manifest:
    lessons[row["track"]][row["lesson"]] += 1
assert audit == {
    "questions": 80,
    "ideas": 80,
    "tracks": {"est2": 40, "sat": 40},
    "lessons": {track: dict(sorted(counts.items())) for track, counts in sorted(lessons.items())},
    "classification_only": True,
    "new_answer_certification": False,
}

match = re.search(r"jsonb_to_recordset\('(\[\{.*?\}\])'::jsonb\)", sql, re.S)
assert match
embedded = json.loads(match.group(1).replace("''", "'"))
expected = [{**row, "fingerprint": fingerprints[row["id"]]} for row in manifest]
assert embedded == expected

assert "revision.est2_sat_idea_expansion.20260930" in sql
assert "already applied; do not rerun" in sql
assert "q.track_id<>x.track" in sql
assert "array[x.track]::text[]" in sql
assert "q.topic<>x.lesson" in sql
assert "public.revision_question_fingerprint" in sql
assert "content duplicates an existing revision item" in sql
assert "new_answer_certification',false" in sql
assert "insert into public.revision_items" in sql
assert not re.search(
    r"\b(update|delete|truncate)\s+public\.(questions|question_keys|exam_questions|exam_sessions|student_scores)\b",
    sql,
    re.I,
)
assert all(row["idea"] not in {"Needs classification", "Other", "Mixed review"} for row in manifest)

print("PASS: second guarded 80-question SAT + EST II expansion; distinct ideas; EST I and source content preserved.")


