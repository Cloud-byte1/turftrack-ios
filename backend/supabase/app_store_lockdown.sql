-- App Store lockdown for the Strike Lab / fairLie Clubhouse.
-- Run AFTER schema.sql in: Dashboard → SQL Editor → New query → Run. Safe to re-run.
--
-- The publishable key ships inside the iPhone app, so anyone can call the API with it.
-- After this script the key can only:
--   • read every Clubhouse table
--   • insert a practice session (sane values only)
--   • insert a feed post (1–500 chars, 0 likes)
--   • call the functions below (profile update, join/progress, like, RSVP)
-- Direct UPDATE / DELETE on any table is denied. Use the service_role key server-side for admin work.

-- 1. Events (RSVP persists) -------------------------------------------------

create table if not exists clubhouse_events (
  id text primary key,
  title text not null,
  detail text,
  when_label text,
  place text,
  attendees integer not null default 0,
  rsvped boolean not null default false,
  created_at timestamptz not null default now()
);

alter table clubhouse_events enable row level security;

-- 2. Replace dev-open write policies ----------------------------------------

drop policy if exists "public write profiles" on profiles;
drop policy if exists "public write sessions" on sessions;
drop policy if exists "public write members" on clubhouse_members;
drop policy if exists "public write challenges" on clubhouse_challenges;
drop policy if exists "public write feed" on clubhouse_feed;
drop policy if exists "public write announcements" on clubhouse_announcements;

drop policy if exists "public read events" on clubhouse_events;
create policy "public read events" on clubhouse_events for select using (true);

drop policy if exists "app insert sessions" on sessions;
create policy "app insert sessions" on sessions for insert
  with check (
    score between 0 and 100
    and swings between 0 and 1000
    and char_length(club) between 1 and 40
  );

drop policy if exists "app insert feed" on clubhouse_feed;
create policy "app insert feed" on clubhouse_feed for insert
  with check (
    char_length(btrim(text)) between 1 and 500
    and char_length(author) between 1 and 60
    and likes = 0
  );

-- 3. Narrow write functions -------------------------------------------------

create or replace function update_profile(
  p_display_name text,
  p_handle text,
  p_handicap numeric,
  p_bio text,
  p_location text,
  p_preferred_clubs text[],
  p_streak_days integer
) returns setof profiles
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_name text := left(coalesce(nullif(btrim(p_display_name), ''), 'Golfer'), 60);
  v_initials text;
begin
  v_initials := upper(left(split_part(v_name, ' ', 1), 1) || coalesce(nullif(left(split_part(v_name, ' ', 2), 1), ''), substr(v_name, 2, 1)));
  select id into v_id from profiles order by created_at asc limit 1;
  if v_id is null then
    insert into profiles (display_name) values (v_name) returning id into v_id;
  end if;

  update profiles set
    display_name = v_name,
    handle = left(regexp_replace(coalesce(p_handle, ''), '[^A-Za-z0-9_]', '', 'g'), 30),
    initials = v_initials,
    handicap = least(greatest(coalesce(p_handicap, 18), -10), 54),
    bio = left(coalesce(p_bio, ''), 280),
    location = left(coalesce(p_location, ''), 80),
    preferred_clubs = coalesce(p_preferred_clubs[1:14], preferred_clubs),
    streak_days = least(greatest(coalesce(p_streak_days, 0), 0), 3650),
    updated_at = now()
  where id = v_id;

  update clubhouse_members m set
    name = p.display_name, handle = p.handle, initials = p.initials,
    handicap = p.handicap, streak = p.streak_days
  from profiles p
  where p.id = v_id and m.is_you;

  return query select * from profiles where id = v_id;
end $$;

create or replace function join_challenge(p_id text) returns setof clubhouse_challenges
language sql security definer set search_path = public as $$
  update clubhouse_challenges set joined = true where id = p_id returning *;
$$;

create or replace function log_challenge_progress(p_id text) returns setof clubhouse_challenges
language sql security definer set search_path = public as $$
  update clubhouse_challenges
     set joined = true, progress = least(greatest(target, 1), coalesce(progress, 0) + 1)
   where id = p_id
  returning *;
$$;

create or replace function like_post(p_id uuid) returns setof clubhouse_feed
language sql security definer set search_path = public as $$
  update clubhouse_feed set likes = coalesce(likes, 0) + 1 where id = p_id returning *;
$$;

create or replace function rsvp_event(p_id text) returns setof clubhouse_events
language sql security definer set search_path = public as $$
  update clubhouse_events
     set rsvped = true, attendees = attendees + case when rsvped then 0 else 1 end
   where id = p_id
  returning *;
$$;

grant execute on function update_profile(text, text, numeric, text, text, text[], integer) to anon, authenticated;
grant execute on function join_challenge(text) to anon, authenticated;
grant execute on function log_challenge_progress(text) to anon, authenticated;
grant execute on function like_post(uuid) to anon, authenticated;
grant execute on function rsvp_event(text) to anon, authenticated;

notify pgrst, 'reload schema';
