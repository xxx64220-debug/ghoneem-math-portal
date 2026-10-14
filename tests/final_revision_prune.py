"""Offline integrity checks for the representative Final Revision release."""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content-releases/20260930_final_revision_prune"
audit = json.loads((OUT / "audit.json").read_text())
sql = (OUT / "apply.sql").read_text()

assert audit["before"]["questions"] == 2427
assert audit["before"]["ready"] == 2414
assert audit["after"]["questions"] == 1344
assert sum(track["questions"] for track in audit["after"]["tracks"].values()) == 1344
assert audit["deactivated"]["questions"] == 1083
assert sum(audit["deactivated"]["representative_cap"].values()) == 1070
assert sum(audit["deactivated"]["source_not_ready"].values()) == 13
assert audit["collection_slice_loss"] == 0
assert audit["classification_only"] is True
assert audit["new_answer_certification"] is False
assert audit["deleted_questions"] == 0
assert audit["reversible"] is True

assert "revision.final_revision_representatives.20260930" in sql
assert "already applied; do not rerun" in sql
assert "e7baafb3a3ce792eb2f7401ea4efba1b" in sql
assert "representative_rank>2" in sql
assert "public.revision_question_fingerprint" in sql
assert "A focused collection slice lost all representatives" in sql
assert "Protected question, exam, session, or score data changed" in sql
assert "'new_answer_certification',false" in sql
assert "'deleted_questions',0" in sql
assert "set active=false" in sql

protected = (
    "questions",
    "question_keys",
    "exams",
    "revision_sessions",
    "attempts",
    "attempt_answers",
    "attempt_results",
    "daily_quizzes",
    "daily_progress",
    "practice_notebook",
)
for table in protected:
    assert not re.search(
        rf"\b(update|delete|truncate|alter|drop)\s+(table\s+)?public\.{table}\b",
        sql,
        re.I,
    ), table

assert not re.search(r"\bdelete\s+from\s+public\.revision_items\b", sql, re.I)
print("PASS: representative cap, fingerprint guard, reversible deactivation, and protected-data checks.")
