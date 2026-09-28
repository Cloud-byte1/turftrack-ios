-- Strike Lab / Golf Mat schema for Supabase
-- Run in: Dashboard → SQL Editor → New query → Run

create extension if not exists "pgcrypto";

create table if not exists profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  display_name text not null default 'Golfer',
  handle text unique,
  initials text default 'GL',
  home_club text default 'Strike Lab Range',
  handicap numeric(4,1) default 18.0,
  preferred_clubs text[] default array['7 Iron'],
  bio text default '',
  location text default '',
  streak_days integer default 0,
  target_handicap numeric(4,1) default 12.0,
  weekly_sessions integer default 3,
  focus_club text default '7 Iron',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sessions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) on delete set null,
  club text not null default '7 Iron',
  when_label text default 'Just now',
  distance text default '0 yds',
  score integer default 0,
  swings integer default 0,
  tone text default 'warm',
  best_carry_yds integer,
  avg_ball_mph numeric,
  best_ball_mph numeric,
  avg_club_mph numeric,
  avg_smash numeric,
  radar_hit_pct integer default 0,
  avg_attack_deg numeric,
  avg_path_deg numeric,
  avg_heel_pct integer,
  avg_center_pct integer,
  avg_toe_pct integer,
  centered_pct integer default 0,
  swing_snapshots jsonb default '[]'::jsonb,
  raw_swings jsonb default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists clubhouse_members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  handle text,
  initials text,
  handicap numeric(4,1),
  rank integer,
  score integer default 0,
  swings integer default 0,
  streak integer default 0,
  is_you boolean default false
);

create table if not exists clubhouse_challenges (
  id text primary key,
  title text not null,
  detail text,
  progress integer default 0,
  target integer default 1,
  ends_at timestamptz,
  joined boolean default false,
  reward text
);

create table if not exists clubhouse_feed (
  id uuid primary key default gen_random_uuid(),
  author text not null,
  text text not null,
  when_label text default 'Just now',
  likes integer default 0,
  created_at timestamptz not null default now()
);

create table if not exists clubhouse_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  created_at timestamptz not null default now()
);

-- Starter challenges (progress is tracked per golfer after auth_migration.sql).
-- No demo golfers, posts, or events are seeded: the Clubhouse shows real accounts only.
insert into clubhouse_challenges (id, title, detail, progress, target, ends_at, joined, reward)
values
  ('ch_center', 'Center-face week', 'Land 12 centered strikes with a 7 iron.', 0, 12, null, false, '+3 clubhouse points'),
  ('ch_ballspeed', 'Honest ball speed', 'Post 8 radar-measured swings over 95 mph.', 0, 8, null, false, 'Radar badge')
on conflict (id) do nothing;

insert into clubhouse_announcements (title, body)
select 'Welcome to the Clubhouse',
       'Save a GolfMat session to appear on the leaderboard. Scores come from real mat sessions only; simulated swings never count.'
where not exists (select 1 from clubhouse_announcements limit 1);

-- Dev-friendly policies (tighten once auth is on)
alter table profiles enable row level security;
alter table sessions enable row level security;
alter table clubhouse_members enable row level security;
alter table clubhouse_challenges enable row level security;
alter table clubhouse_feed enable row level security;
alter table clubhouse_announcements enable row level security;

do $$ begin
  create policy "public read profiles" on profiles for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public write profiles" on profiles for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public read sessions" on sessions for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public write sessions" on sessions for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public read members" on clubhouse_members for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public write members" on clubhouse_members for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public read challenges" on clubhouse_challenges for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public write challenges" on clubhouse_challenges for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public read feed" on clubhouse_feed for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public write feed" on clubhouse_feed for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public read announcements" on clubhouse_announcements for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "public write announcements" on clubhouse_announcements for all using (true) with check (true);
exception when duplicate_object then null; end $$;
