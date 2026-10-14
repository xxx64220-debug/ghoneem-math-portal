# Students & subscriptions

The primary Students destination now contains **Accounts & groups** and **Subscriptions & payments**. The second panel retains payment recording, payment history, filters and course bulk actions. The former top-level Course access route remains supported internally, and navigation highlights the same Students destination.

**Create student** and **Manage student** share one form:

- Account name and active/suspended status.
- Every selected course: active/paused access, course label, start/end timestamps, payment status.
- Matching teaching-group checkboxes. Default all-students cohorts are retained automatically.

The roster shows subscription status/dates/payment state and groups together. Its global track filter includes paused enrollments. Search/filter/pagination and existing bulk account selection remain available. Staff account creation and editing keep their separate permissions; instructors retain the scoped read-only student roster.

Saves use the existing enrollment, guarded course-access and profile endpoints in stages. Course version guards reject conflicting changes; successful steps are retained on retry. Matching already-saved course fields reconcile a lost response safely. Completed steps are not rolled back automatically if a later step fails.

The additive `student-groups` Edge Function uses the existing shared active-user/session and administrator checks. It validates a student target and matching course enrollment (including future/paused courses) before applying explicit add/remove lists. Changes are restricted to that user's memberships, preserve default cohorts, retain other students, and are idempotent on retry. The endpoint keeps service credentials server-side and requires JWT verification. This was deployed as version 1 to the existing production project. No database migration or schema change was applied: the native migration request expired twice, and read checks confirmed no new setup RPCs had been created.

Existing enrollments are never deleted; unticking an existing course pauses it. Payment status updates do not insert receipts. Attempts, results, assignments, payments, other students and bank content remain unchanged.

Auth account creation continues through the existing admin-users endpoint, initially without track access. When it returns a user ID, the form suspends the new account while setup completes, retains its ID across setup/read failures and clears the password; retry completes that same account. Account, course and membership saves are separate requests. If the account-creation response itself is lost, check the account list before attempting creation again. Successfully created accounts remain manageable if the form is closed before subscription setup finishes.

Validation uses `tests/student_management_ui.test.cjs`, `tests/student_groups.test.cjs` and related admin regressions, plus the existing disposable PostgreSQL course-management gates. Tests cover all tracks, single-student group isolation, idempotent retry, student/instructor denial, default cohorts, initial setup-read failure, retry after save failure, payment/date preservation, paused-course visibility and source/dist parity. No production student writes are used for testing. Visual browser QA was unavailable in this session.

October 15 group update: each course now has a preferred daily-quiz group. Automatic mode uses a teaching group only when one is active, otherwise it retains the parent track settings. `student-groups` version 2 accepts those administrator preferences and permits instructors to change memberships only in their own groups. Membership guards enforce the same track; removing a preferred membership clears its preference without rewriting past quizzes.
