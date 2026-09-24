begin;

-- Give active instructors explicit access to the EST Math 2 track. Admins
-- already receive all-track access through the existing is_admin() policy.
insert into public.instructor_tracks (user_id, track_id)
select p.id, 'est2'
from public.profiles p
where p.role = 'instructor'
  and p.status = 'active'
on conflict (user_id, track_id) do nothing;

-- Make every published EST Math 2 exam self-paced and visible to the existing
-- all-students group. The NOT EXISTS guard keeps this release idempotent.
insert into public.assignments (exam_id, group_id, user_id, open_at, close_at)
select e.id, g.id, null, null, null
from public.exams e
join public.groups g
  on g.track_id = 'est2'
 and g.name = 'EST Math 2 — all students'
where e.track_id = 'est2'
  and e.is_published
  and not exists (
    select 1
    from public.assignments a
    where a.exam_id = e.id
  );

commit;
