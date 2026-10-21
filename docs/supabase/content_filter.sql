-- fairLie Clubhouse content filter (App Review guideline 1.2).
--
-- Server-side twin of `ContentFilter` in TurfTrack/Cloud/CloudModels.swift. The app screens
-- text before upload; these triggers reject anything that slips past it (old app builds,
-- direct API calls). Keep the word lists in both places in sync.
--
-- Rejections raise 'fairlie_content_filter', which the app maps to a friendly message
-- (`SupabaseError.isContentRejected`).
--
-- Run once in the Supabase SQL editor, after auth_migration.sql. Safe to re-run.

create or replace function fairlie_text_blocked(p_text text) returns boolean
language sql immutable as $$
  with t as (
    select lower(coalesce(p_text, '')) as orig,
           translate(lower(coalesce(p_text, '')), '01345@$', 'oieasas') as leet
  ), c as (
    select orig, leet, regexp_replace(leet, '([a-z])\1+', '\1', 'g') as collapsed from t
  )
  select
    -- Links, emails, phone numbers: the Clubhouse asks for no personal contact details.
    orig ~ '(https?://|www\.|\m[a-z0-9-]+\.(com|net|org|io|app|co|me|ly)\M)'
    or orig ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
    or (orig ~ '\d[\d\s().-]{6,}\d' and length(regexp_replace(orig, '\D', '', 'g')) >= 7)
    -- Whole words, as written.
    or leet ~ '\m(asshole|assholes|bastard|bitch|bitches|bullshit|chink|cock|cunt|dick|dicks|dyke|fag|faggot|kike|kys|nigga|nigger|porn|pussy|rape|rapist|retard|retarded|shit|slut|sluts|spic|tranny|twat|wanker|whore)\M'
    -- Words with no doubled letters also match stretched spellings ("biiitch").
    or collapsed ~ '\m(bastard|bitch|bitches|chink|cock|cunt|dick|dicks|dyke|fag|kike|kys|porn|rape|rapist|retard|retarded|shit|slut|sluts|spic|twat|wanker|whore)\M'
    -- Stems at the start of any word ("fucking", "shitty").
    or leet ~ '\m(fuck|motherfuck|shit|cunt|nigg|fagg|whore)'
    or collapsed ~ '\m(fuck|motherfuck|shit|cunt|whore)'
    or leet ~ 'kill\s+(yourself|urself)'
  from c;
$$;

create or replace function fairlie_check_feed_text() returns trigger
language plpgsql as $$
begin
  if fairlie_text_blocked(new.text) then
    raise exception 'fairlie_content_filter' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists fairlie_content_filter on clubhouse_feed;
create trigger fairlie_content_filter
  before insert or update of text on clubhouse_feed
  for each row execute function fairlie_check_feed_text();

-- Display name, bio, and city are visible to other golfers on the leaderboard and profile.
create or replace function fairlie_check_profile_text() returns trigger
language plpgsql as $$
begin
  if fairlie_text_blocked(concat_ws(E'\n', new.display_name, new.bio, new.location)) then
    raise exception 'fairlie_content_filter' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists fairlie_content_filter on profiles;
create trigger fairlie_content_filter
  before insert or update of display_name, bio, location on profiles
  for each row execute function fairlie_check_profile_text();

-- Quick check after running (expect: f, t, t):
-- select fairlie_text_blocked('Great 7 iron session in Nigeria'),
--        fairlie_text_blocked('fuuuuck this'),
--        fairlie_text_blocked('call me 555 123 4567');
