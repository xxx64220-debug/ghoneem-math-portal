-- Keep one assignment for each exam/target pair. Prefer the row that already
-- owns attempts, then the oldest row. Redundant rows with no attempts are safe
-- to remove.
with ranked as (
  select
    a.id,
    row_number() over (
      partition by a.exam_id, a.group_id, a.user_id
      order by
        (select count(*) from public.attempts t where t.assignment_id = a.id) desc,
        a.created_at asc,
        a.id
    ) as keep_rank,
    (select count(*) from public.attempts t where t.assignment_id = a.id) as attempt_count
  from public.assignments a
)
delete from public.assignments a
using ranked r
where a.id = r.id
  and r.keep_rank > 1
  and r.attempt_count = 0;

-- NULLS NOT DISTINCT makes group assignments (null user_id) and direct
-- assignments (null group_id) unique in the same way.
create unique index if not exists assignments_unique_exam_target_idx
on public.assignments (exam_id, group_id, user_id) nulls not distinct;
