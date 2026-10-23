"""Emit the exact release with its final COMMIT changed to ROLLBACK."""
from pathlib import Path

sql=Path(__file__).with_name('apply.sql').read_text()
assert sql.endswith('\ncommit;\n')
print(sql[:-len('commit;\n')]+'rollback;')
