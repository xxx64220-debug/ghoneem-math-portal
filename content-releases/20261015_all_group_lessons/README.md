# All parent-track lessons — applied October 15, 2026 (Cairo)

The arbitrary ten-lesson cap is removed from both guarded group-save endpoints and both editors. Groups can select every lesson provided by their parent track. Select-all and clear controls are available in the group editor and course-plan editor. Empty selection continues to inherit track settings.

The forward SQL patch was applied once to the existing production project. Read-only verification confirmed the lesson-count cap is absent from both functions while parent-track and minimum eligible-question guards remain. No existing group selection, membership, assignment or student history was rewritten. Daily quizzes remain five questions; already-opened sets remain frozen. Do not replay the applied patch.

Validation includes both DOM editors saving thirteen lessons, disposable PostgreSQL saves through both real group endpoints, rejection of invalid lessons, and preservation of the five-question daily contract. Browser visual QA was unavailable.
