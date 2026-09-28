-- Remove the demo rows seeded by schema.sql / app_store_lockdown.sql so the live
-- Clubhouse only shows real golfers. Run AFTER auth_migration.sql. Safe to re-run.

delete from clubhouse_members where user_id is null;
delete from clubhouse_feed where user_id is null;
delete from sessions where user_id is null;
delete from profiles where user_id is null;

delete from clubhouse_events where id in ('ev_tuesday', 'ev_sat');
delete from clubhouse_announcements where title in ('Tuesday range night', 'Handicap sync');

insert into clubhouse_announcements (title, body)
select 'Welcome to the Clubhouse',
       'Save a GolfMat session to appear on the leaderboard. Scores come from real mat sessions only; simulated swings never count.'
where not exists (select 1 from clubhouse_announcements);

update clubhouse_challenges set ends_at = null where ends_at < now();

notify pgrst, 'reload schema';
