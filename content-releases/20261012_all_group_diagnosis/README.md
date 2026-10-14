# All-course diagnosis rollout — October 12, 2026

Extends the existing read-only staff_group_exam_evidence(uuid, uuid[]) function to SAT, EST I, EST II and EST English. The assessment determines the track. Caller, enrollment, owned-group and review-release checks remain enforced; answers and keys are never returned.

apply.sql checks the previously reviewed production function definition hash before replacing the function. rollback.sql restores the previous EST-only definition. This release writes no scores, attempts, answers, keys, assignments, groups or enrollments. Revoke/grant preserves the authenticated-only callable signature. Isolated SQL and client regressions pass; production install verification and Site deployment are recorded after rollout.

Applied successfully to the existing Supabase project. Live function definition MD5: fe3dd234bfae777ba1747a121b40dd0d. Verified security definer with empty search path, no anonymous execute permission, authenticated execute permission, and exam-derived track scope. No new tables or RLS policies were introduced.

Security advisor review: authenticated security-definer execution remains intentional for this narrow staff RPC, because it aggregates reviewed results while checking the caller role, track, enrollment and owned group itself. Anonymous execution is revoked, student calls are rejected, and only counts are returned. See [Supabase advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Other reported items concern existing no-policy tables and project Auth password settings; this rollout does not alter them.
