# fairLie (iOS)

Native iPhone app for the FairLie smart-mat system — the full product, not just the lab.

## App

- **Sign in / Create account** then **profile setup** (city, handicap, skill, bag)
- **Home** — strike score, start session, putting snapshot, Clubhouse banner
- **Practice** — Strike Lab (BLE mat + separate BLE radar, zero, heatmap, grades, below-average simulator)
- **Play** — Supabase Clubhouse challenges (join, log strikes) plus club battles
- **Progress** — saved sessions and score trend, synced to Supabase
- **Club** — bag, trophies, friends, live leaderboard, announcements, feed (post + like), device
- **Profile & Settings** — bio, handicap, saved-session stats, privacy, data export, delete account, sign out

Sign-in supports email/password and **Sign in with Apple**. Sign-in details stay
on-device; deleting your account removes them immediately.

## Two ESP32s

- **Mat ESP** (FSR pads) advertises `GolfMat` — tap **Mat BLE**.
- **Radar ESP** (XM125) advertises `GolfMatRadar`, service `0xAB20` — tap **Radar BLE**.
  Flash `radar_esp/radar_stream.ino` from the `golf_mat` repo. Each mat strike
  takes ball speed from the latest radar reading within 0.75 s.

## Supabase

Sessions, the profile, and the Clubhouse (members, challenges, feed,
announcements) use the same tables as the `golf_mat` backend
(`backend/supabase/schema.sql`).

`TurfTrack/Config/Supabase.plist` holds the project URL and **publishable** key, so
every Xcode build connects. The publishable key ships in the app binary by design;
never put the `service_role` key here. Without the plist the app runs on sample data.

Run these in the Supabase SQL Editor, in order: `schema.sql`,
[`docs/supabase/app_store_lockdown.sql`](docs/supabase/app_store_lockdown.sql), then
[`docs/supabase/auth_migration.sql`](docs/supabase/auth_migration.sql).

### Accounts (Supabase Auth)

Sign-in uses Supabase Auth — email + password or Sign in with Apple. Tokens live in
the Keychain and refresh automatically. Row-level security scopes data to each golfer:

- **Private:** practice sessions, challenge progress, RSVPs, likes
- **Shared:** leaderboard (`clubhouse_members`, one row per golfer, stats kept in sync
  by a trigger), feed posts (author stamped server-side), events, announcements
- **Delete account** (Settings) calls `delete_my_account()`, which removes the auth
  user and everything they own (App Review 5.1.1(v))

Supabase dashboard setup:

1. **Authentication → Sign In / Providers → Apple:** enable it and add
   `com.fairlie.turftrack` under Client IDs (native sign-in needs no secret key)
2. **Authentication → Sign In / Providers → Email:** turn **Confirm email** off for the
   smoothest review, or leave it on — the app tells new golfers to check their inbox
3. **Authentication → URL Configuration:** set the Site URL to your support site so
   password-reset links land somewhere sensible

Give App Review a demo account (email + password) in App Store Connect.

The Clubhouse feed is user-generated content: each post has **Report**, **Hide**,
and **Block author**, and golfers can delete their own posts (App Review Guideline
1.2). Reports email `AppConfig.supportEmail`.

## Open & run

1. Clone on a Mac and open `TurfTrack.xcodeproj`
2. Set your Team under Signing & Capabilities, and enable **Sign in with Apple** on
   the `com.fairlie.turftrack` App ID
3. Run on an iPhone (iOS 16+)

Pair GolfMat over BLE from Practice after you sign in, or use the built-in swing
simulator to explore the app without hardware.

## Shipping to the App Store

- [`docs/APP_STORE_LAUNCH.md`](docs/APP_STORE_LAUNCH.md) — full submission checklist:
  legal, technical, metadata, questionnaires, review notes
- [`docs/brand/LOGO_PROMPT.md`](docs/brand/LOGO_PROMPT.md) — icon and logo prompts
  plus the brand palette
- [`docs/legal/privacy-policy.md`](docs/legal/privacy-policy.md) and
  [`docs/legal/terms-of-use.md`](docs/legal/terms-of-use.md) — host these at the URLs
  in `AppConfig.swift` before submitting
