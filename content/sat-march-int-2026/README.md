# March 2026 International Version C math

The uploaded 101-page PDF contains two 22-question math modules on PDF pages 55–98. The original embedded image for each of the 44 math questions was read directly; this avoids the watermark and preserves the graph and table details that OCR loses. The original PDF SHA-256 is `57ba41043b3052bd2bd7159288b5439e619baf3542447c914e8c17307d3394bb`. It remains in the user's supplied files, outside the public repository.

`questions.json` has 40 independently solved questions with checked choices or numeric answers, worked explanations, topic labels, and source identifiers. Ten graph, triangle, scatterplot, and table items carry compressed original-image figures in the database. The derived image hashes are recorded in `image-hashes.json`. The generated SQL is not committed because it includes source image bytes.

## Held source questions

- Module 1 Q6 (page 60): the two printed equations `y=9x−3` and `y=x−3²` have intersection `(−3/4,−39/4)`, absent from A–D.
- Module 1 Q12 (page 66): 145.0 inches per second equals 145/12 feet per second. Neither this fraction nor a terminating exact decimal fits the SAT's short student-response entry; the current grader requires exact numeric equality to within 10⁻⁶.
- Module 1 Q18 (page 72): the printed `f(x)=64ˣ` gives `f(3)=262,144`, absent from all four choices.
- Module 1 Q22 (page 76): the visible literal equation `4x−9−4=7x−9+4` gives `x−9=−35/3`, absent from A–D. The likely intended grouped expression is not established by the source image.

These four are not inserted into the scored bank. Original image and OCR are retained in the user's PDF for repair with a faithful replacement version.

## Reproduction and checks

Run `python3 content/sat-march-int-2026/build.py /path/to/original.pdf /tmp/march-int-release.sql`. The build refuses any PDF with a different checksum. The output inserts only new stable IDs, rejects exact normalized stem or source-code duplicates, inserts private keys and SAT-only Final Revision entries, and verifies all 40 in one transaction. Source graph images are derived from the embedded question images and shown with each affected problem. The transaction was executed with its final `COMMIT` replaced by `ROLLBACK` in the connected production database before release.

The March US and Elite May PDFs have separate reviewed intakes in this repository. This release counts only its own 40 questions; the College Panda workbook is still outstanding.
