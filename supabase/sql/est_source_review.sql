-- Instructor-only archive. Never selectable as exam questions until separately reviewed.
begin;
create table if not exists public.est_source_review (
 id text primary key,
 track_id text not null references public.tracks(id),
 source_document text not null,
 source_code text not null,
 source_page integer not null,
 source_section text not null,
 review_status text not null,
 source_text text not null default '',
 review_note text not null default '',
 worked_answer jsonb,
 question_id uuid references public.questions(id),
 duplicate_of text,
 image_path text not null,
 image_key_base64 text not null,
 image_iv_base64 text not null,
 image_sha256 text not null,
 updated_at timestamptz not null default now()
);
alter table public.est_source_review enable row level security;
revoke all on public.est_source_review from anon,authenticated;
grant select on public.est_source_review to authenticated;
grant all on public.est_source_review to service_role;
drop policy if exists est_source_review_staff on public.est_source_review;
create policy est_source_review_staff on public.est_source_review for select to authenticated
 using (public.staff_can_touch_track(track_id));
commit;
