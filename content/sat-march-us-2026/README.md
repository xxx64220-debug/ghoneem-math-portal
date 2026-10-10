# March 2026 US Version B, math modules

The source has 44 math questions, 22 per module on PDF pages 55–98. Thirty-eight questions were independently solved, checked against the source images and answer sheet (page 99), and added to graded SAT practice and Final Revision. Nine items carry their original graph/table/diagram images. `build.py` verifies the source SHA-256 and creates transactional SQL; generated SQL and the supplied PDF remain outside git.

```sh
python3 content/sat-march-us-2026/build.py 'SAT March US Version B @DSATaz_260428_214855.pdf' /tmp/march-us-release.sql
```

## Six questions excluded from graded practice

| Source | Reason |
|---|---|
| Module 1 Q6, PDF page 60 | The printed equation appears linear yet asks for a product of multiple solutions, and its supplied answer 36/5 cannot be derived from it. |
| Module 1 Q19, PDF page 73 | The displayed equation `97−x+5=95` gives x=7; the answer sheet marks 14. |
| Module 2 Q3, PDF page 79 | The printed expression `3x+57x−8` has a+b=60 when written as ax²+bx+c; the answer sheet says 32. |
| Module 2 Q16, PDF page 92 | The exact answer `128+32√85+16√97` cannot be represented in the numeric-only grid-in field. |
| Module 2 Q17, PDF page 93 | The displayed equation `76−x+3=73` gives x=6; the answer sheet marks 12. |
| Module 2 Q19, PDF page 95 | The typeset `f a+1=2a` has lost function parentheses. It gives different answers for `f(a+1)` versus `f(a)+1`. |

These exclusions preserve the originals in the user's supplied PDF and avoid presenting an incorrect graded answer. Module 1 Q11's printed `point 98` is transcribed as `(9,8)` because all four supplied choices and its key establish the intended coordinates; its explanation calls out the source punctuation loss.
