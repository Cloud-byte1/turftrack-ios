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

1. Copy `TurfTrack/Config/Supabase.example.plist` to `TurfTrack/Config/Supabase.plist`
2. Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the publishable key)

`Supabase.plist` is gitignored. Without it the app runs on local sample data.
The schema's row-level security policies are dev-open (anyone with the key can
write); tighten them before shipping.

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
