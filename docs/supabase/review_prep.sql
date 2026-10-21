-- One-off cleanup before App Review so the Clubhouse looks live. Run in the SQL editor.
-- Read each step before running it.

-- 1. See every account; delete throwaway test users (cascades to their profile and rows).
select id, email, created_at, last_sign_in_at from auth.users order by created_at;
-- delete from auth.users where email in ('<test1@example.com>', '<test2@example.com>');

-- 2. Challenges: drop the expired end date and "before Sunday" wording.
update clubhouse_challenges set ends_at = null where ends_at < now();
update clubhouse_challenges set detail = 'Land 12 centered strikes with a 7 iron.' where id = 'ch_center';

-- 3. An upcoming event.
insert into clubhouse_events (id, title, detail, when_label, place)
values ('ev_launch', 'Strike night', 'Bring your GolfMat and chase centered contact.', 'Thursdays, 7 PM', 'Your local range')
on conflict (id) do nothing;

-- 4. Seed posts: sign in to the app with the team account and post a couple of range wins
--    so the feed isn't empty (posts must come from a real account; the trigger stamps the author).

notify pgrst, 'reload schema';
