-- Clubhouse post reports (App Review guideline 1.2).
--
-- The app calls report_post() from the ••• menu, so a report reaches the team even on a
-- device with no Mail account. Review open reports in Table Editor → post_reports, delete
-- the offending post with the service role, and set reviewed_at. Aim to act within 24 hours.
--
-- Run once in the Supabase SQL editor, after auth_migration.sql. Safe to re-run.

create table if not exists post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references clubhouse_feed(id) on delete set null,
  reporter_id uuid references auth.users(id) on delete set null,
  post_author text,
  post_author_id uuid,
  post_text text,
  reason text not null default '',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

-- No policies: only report_post() and the service role can touch it.
alter table post_reports enable row level security;

create or replace function report_post(p_id uuid, p_reason text default '') returns setof post_reports
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode = '42501'; end if;
  return query
  insert into post_reports (post_id, reporter_id, post_author, post_author_id, post_text, reason)
  select f.id, auth.uid(), f.author, f.user_id, f.text, left(coalesce(p_reason, ''), 500)
  from clubhouse_feed f where f.id = p_id
  returning *;
end $$;

revoke execute on function report_post(uuid, text) from public, anon;
grant execute on function report_post(uuid, text) to authenticated;

notify pgrst, 'reload schema';
