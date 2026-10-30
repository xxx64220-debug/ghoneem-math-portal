# SAT full exam review

Completed paired SAT papers open as one full review from either module's saved result and immediately after submitting Module 2. A **Review full exam** button appears on completed exam cards. The review shows the sum of the two saved raw grades, followed by Module 1 and Module 2, each with its own score, question numbers, choices, responses, explanations and figures. No scaled conversion is invented.

The server pairs attempts by chronology within the same student, SAT track and exam-set code. A Module 2 uses the last Module 1 completed before it began. A Module 1 uses the most recent completed Module 2 before the next Module 1 starts. This preserves historical sittings, including a retake of only Module 2. Incomplete pairs stay as individual results with a completion notice.

Legacy score-only Module 1 answers become available only once the corresponding Module 2 review is open. Each module still respects its own release timestamp, verified grade and instructor-release policy. The read-only functions preserve scores, answers, question keys, attempts and course-history access. The public RPC and private module renderer are executable only by `service_role`; the existing Edge Functions continue verifying the caller and ownership.

Release: `content-releases/20261017_sat_full_review/apply.sql` is transactional and checks the prior function fingerprint. Do not replay it after application. `before.sql` is the exact prior public function for rollback. Source functions are in `supabase/sql/attempt_module_review.sql` and `supabase/sql/sat_full_exam_review.sql`; install these after earlier review definitions in a new database.

Validation: isolated PostgreSQL WASM regression coverage for 44-question rendering, retake boundaries, ownership, access after practice expiry, pending grades, delayed release, instructor release, unchanged stored results and single-paper SAT/EST behavior; client and DOM tests for the combined score, both modules, figures and the submission/history paths. Browser QA is unavailable in this environment.
