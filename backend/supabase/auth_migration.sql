-- Supabase Auth migration for the fairLie / Strike Lab Clubhouse.
-- Run AFTER schema.sql and app_store_lockdown.sql in: Dashboard → SQL Editor → New query → Run.
-- Safe to re-run.
--
-- Every golfer signs in with Supabase Auth (email or Sign in with Apple). After this script:
--   • profiles: readable by signed-in golfers, each golfer inserts/updates only their own row
--   • sessions: private — each golfer reads, inserts, and deletes only their own
--   • clubhouse_members: public leaderboard, one row per golfer, kept in sync by triggers
--   • clubhouse_feed: public read, signed-in golfers post as themselves and delete their own posts
--   • challenge progress, RSVPs, and likes are stored per golfer
--   • delete_my_account() removes the auth user and, via cascades, everything they own

create extension if not exists "pgcrypto";

-- 1. Columns -----------------------------------------------------------------

alter table profiles add column if not exists skill text default 'Intermediate';
alter table profiles add column if not exists needs_setup boolean not null default true;
update profiles set needs_setup = false where user_id is null;

alter table sessions add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table sessions alter column user_id set default auth.uid();
create index if not exists sessions_user_id_idx on sessions(user_id, created_at desc);

alter table clubhouse_members add column if not exists user_id uuid references auth.users(id) on delete cascade;
do $$ begin
  alter table clubhouse_members add constraint clubhouse_members_user_id_key unique (user_id);
exception when duplicate_object or duplicate_table then null; end $$;
delete from clubhouse_members where is_you and user_id is null;
update clubhouse_members set is_you = false where is_you;

alter table clubhouse_feed add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table clubhouse_feed alter column user_id set default auth.uid();

-- Global flags from the single-user era are now per golfer.
update clubhouse_challenges set joined = false, progress = 0;
update clubhouse_events set rsvped = false;

-- 2. Per-golfer tables ---------------------------------------------------------

create table if not exists challenge_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_id text not null references clubhouse_challenges(id) on delete cascade,
  progress integer not null default 0,
  joined boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, challenge_id)
);

create table if not exists event_rsvps (
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id text not null references clubhouse_events(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, event_id)
);

create table if not exists post_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references clubhouse_feed(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

alter table challenge_progress enable row level security;
alter table event_rsvps enable row level security;
alter table post_likes enable row level security;

drop policy if exists "own progress" on challenge_progress;
create policy "own progress" on challenge_progress for select using (user_id = auth.uid());
drop policy if exists "own rsvps" on event_rsvps;
create policy "own rsvps" on event_rsvps for select using (user_id = auth.uid());
drop policy if exists "own likes" on post_likes;
create policy "own likes" on post_likes for select using (user_id = auth.uid());

-- 3. Profiles ----------------------------------------------------------------

create or replace function make_handle(p_name text, p_user uuid) returns text
language sql immutable as $$
  select left(coalesce(nullif(lower(regexp_replace(coalesce(p_name, ''), '[^A-Za-z0-9]', '', 'g')), ''), 'golfer'), 20)
         || '_' || substr(replace(p_user::text, '-', ''), 1, 5);
$$;

create or replace function make_initials(p_name text) returns text
language sql immutable as $$
  select upper(
    left(split_part(btrim(coalesce(p_name, 'Golfer')), ' ', 1), 1)
    || coalesce(nullif(left(split_part(btrim(coalesce(p_name, 'Golfer')), ' ', 2), 1), ''),
                substr(btrim(coalesce(p_name, 'Golfer')), 2, 1))
  );
$$;

create or replace function sanitize_profile() returns trigger
language plpgsql set search_path = public as $$
begin
  new.display_name := left(coalesce(nullif(btrim(new.display_name), ''), 'Golfer'), 60);
  new.initials := left(coalesce(nullif(btrim(new.initials), ''), make_initials(new.display_name)), 3);
  new.handicap := least(greatest(coalesce(new.handicap, 18), -10), 54);
  new.bio := left(coalesce(new.bio, ''), 280);
  new.location := left(coalesce(new.location, ''), 80);
  new.skill := left(coalesce(new.skill, 'Intermediate'), 30);
  new.preferred_clubs := coalesce(new.preferred_clubs[1:14], array['7 Iron']);
  new.streak_days := least(greatest(coalesce(new.streak_days, 0), 0), 3650);
  if new.user_id is not null and (new.handle is null or tg_op = 'INSERT') then
    new.handle := make_handle(new.display_name, new.user_id);
  end if;
  if tg_op = 'UPDATE' then
    new.user_id := old.user_id;
    new.handle := coalesce(old.handle, new.handle);
    new.updated_at := now();
  end if;
  return new;
end $$;

drop trigger if exists profiles_sanitize on profiles;
create trigger profiles_sanitize before insert or update on profiles
  for each row execute function sanitize_profile();

create or replace function sync_member_from_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.user_id is null then return new; end if;
  insert into clubhouse_members (user_id, name, handle, initials, handicap, streak, score, swings, is_you)
  values (new.user_id, new.display_name, new.handle, new.initials, new.handicap, new.streak_days, 0, 0, false)
  on conflict (user_id) do update set
    name = excluded.name,
    handle = excluded.handle,
    initials = excluded.initials,
    handicap = excluded.handicap,
    streak = excluded.streak;
  return new;
end $$;

drop trigger if exists profiles_sync_member on profiles;
create trigger profiles_sync_member after insert or update on profiles
  for each row execute function sync_member_from_profile();

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_name text := left(coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Golfer'
  ), 60);
begin
  insert into profiles (user_id, display_name, initials, needs_setup)
  values (new.id, v_name, make_initials(v_name), true)
  on conflict (user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Backfill auth users created before this script.
insert into profiles (user_id, display_name, initials, needs_setup)
select u.id,
       left(coalesce(nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'Golfer'), 60),
       make_initials(coalesce(nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'Golfer')),
       true
from auth.users u
on conflict (user_id) do nothing;

drop policy if exists "public read profiles" on profiles;
drop policy if exists "signed-in read profiles" on profiles;
create policy "signed-in read profiles" on profiles for select to authenticated using (true);
drop policy if exists "own insert profile" on profiles;
create policy "own insert profile" on profiles for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "own update profile" on profiles;
create policy "own update profile" on profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4. Sessions ----------------------------------------------------------------

drop policy if exists "public read sessions" on sessions;
drop policy if exists "app insert sessions" on sessions;
drop policy if exists "own read sessions" on sessions;
drop policy if exists "own insert sessions" on sessions;
drop policy if exists "own delete sessions" on sessions;

create policy "own read sessions" on sessions for select to authenticated using (user_id = auth.uid());
create policy "own insert sessions" on sessions for insert to authenticated
  with check (
    user_id = auth.uid()
    and score between 0 and 100
    and swings between 0 and 1000
    and char_length(club) between 1 and 40
  );
create policy "own delete sessions" on sessions for delete to authenticated using (user_id = auth.uid());

create or replace function refresh_member_stats() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := coalesce(new.user_id, old.user_id);
begin
  if v_user is null then return null; end if;
  update clubhouse_members m set
    score = coalesce((select round(avg(s.score))::int from sessions s where s.user_id = v_user and s.score > 0), 0),
    swings = coalesce((select sum(s.swings)::int from sessions s where s.user_id = v_user), 0)
  where m.user_id = v_user;
  return null;
end $$;

drop trigger if exists sessions_member_stats on sessions;
create trigger sessions_member_stats after insert or delete on sessions
  for each row execute function refresh_member_stats();

-- 5. Feed --------------------------------------------------------------------

create or replace function stamp_feed_author() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.user_id := auth.uid();
  new.likes := 0;
  new.author := coalesce((select display_name from profiles where user_id = auth.uid()), left(btrim(new.author), 60));
  return new;
end $$;

drop trigger if exists feed_stamp_author on clubhouse_feed;
create trigger feed_stamp_author before insert on clubhouse_feed
  for each row execute function stamp_feed_author();

drop policy if exists "app insert feed" on clubhouse_feed;
drop policy if exists "own insert feed" on clubhouse_feed;
drop policy if exists "own delete feed" on clubhouse_feed;
create policy "own insert feed" on clubhouse_feed for insert to authenticated
  with check (
    user_id = auth.uid()
    and char_length(btrim(text)) between 1 and 500
    and char_length(author) between 1 and 60
    and likes = 0
  );
create policy "own delete feed" on clubhouse_feed for delete to authenticated using (user_id = auth.uid());

-- 6. Functions ---------------------------------------------------------------

drop function if exists update_profile(text, text, numeric, text, text, text[], integer);

create or replace function list_challenges() returns setof clubhouse_challenges
language sql stable security definer set search_path = public as $$
  select c.id, c.title, c.detail,
         coalesce(p.progress, 0), c.target, c.ends_at,
         coalesce(p.joined, false), c.reward
  from clubhouse_challenges c
  left join challenge_progress p on p.challenge_id = c.id and p.user_id = auth.uid()
  order by c.ends_at nulls last, c.id;
$$;

create or replace function list_events() returns setof clubhouse_events
language sql stable security definer set search_path = public as $$
  select e.id, e.title, e.detail, e.when_label, e.place, e.attendees,
         exists (select 1 from event_rsvps r where r.event_id = e.id and r.user_id = auth.uid()),
         e.created_at
  from clubhouse_events e
  order by e.created_at;
$$;

create or replace function join_challenge(p_id text) returns setof clubhouse_challenges
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode = '42501'; end if;
  insert into challenge_progress (user_id, challenge_id, progress, joined)
  values (auth.uid(), p_id, 0, true)
  on conflict (user_id, challenge_id) do update set joined = true, updated_at = now();
  return query select * from list_challenges() where id = p_id;
end $$;

create or replace function log_challenge_progress(p_id text) returns setof clubhouse_challenges
language plpgsql security definer set search_path = public as $$
declare
  v_target integer;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode = '42501'; end if;
  select greatest(coalesce(target, 1), 1) into v_target from clubhouse_challenges where id = p_id;
  if v_target is null then return; end if;
  insert into challenge_progress (user_id, challenge_id, progress, joined)
  values (auth.uid(), p_id, 1, true)
  on conflict (user_id, challenge_id) do update
    set progress = least(v_target, challenge_progress.progress + 1), joined = true, updated_at = now();
  return query select * from list_challenges() where id = p_id;
end $$;

create or replace function like_post(p_id uuid) returns setof clubhouse_feed
language plpgsql security definer set search_path = public as $$
declare
  v_new integer;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode = '42501'; end if;
  insert into post_likes (user_id, post_id) values (auth.uid(), p_id)
  on conflict do nothing;
  get diagnostics v_new = row_count;
  if v_new > 0 then
    update clubhouse_feed set likes = coalesce(likes, 0) + 1 where id = p_id;
  end if;
  return query select * from clubhouse_feed where id = p_id;
end $$;

create or replace function rsvp_event(p_id text) returns setof clubhouse_events
language plpgsql security definer set search_path = public as $$
declare
  v_new integer;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode = '42501'; end if;
  insert into event_rsvps (user_id, event_id) values (auth.uid(), p_id)
  on conflict do nothing;
  get diagnostics v_new = row_count;
  if v_new > 0 then
    update clubhouse_events set attendees = attendees + 1 where id = p_id;
  end if;
  return query select * from list_events() where id = p_id;
end $$;

create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in first' using errcode = '42501'; end if;
  update clubhouse_events e set attendees = greatest(attendees - 1, 0)
    from event_rsvps r where r.event_id = e.id and r.user_id = v_user;
  update clubhouse_feed f set likes = greatest(coalesce(likes, 0) - 1, 0)
    from post_likes l where l.post_id = f.id and l.user_id = v_user;
  delete from profiles where user_id = v_user;
  delete from auth.users where id = v_user;
end $$;

revoke execute on function join_challenge(text) from public, anon;
revoke execute on function log_challenge_progress(text) from public, anon;
revoke execute on function like_post(uuid) from public, anon;
revoke execute on function rsvp_event(text) from public, anon;
revoke execute on function delete_my_account() from public, anon;

grant execute on function join_challenge(text) to authenticated;
grant execute on function log_challenge_progress(text) to authenticated;
grant execute on function like_post(uuid) to authenticated;
grant execute on function rsvp_event(text) to authenticated;
grant execute on function delete_my_account() to authenticated;
grant execute on function list_challenges() to anon, authenticated;
grant execute on function list_events() to anon, authenticated;

revoke execute on function handle_new_user() from public, anon, authenticated;
revoke execute on function sync_member_from_profile() from public, anon, authenticated;
revoke execute on function refresh_member_stats() from public, anon, authenticated;
revoke execute on function stamp_feed_author() from public, anon, authenticated;

notify pgrst, 'reload schema';
