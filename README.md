# fairLie (iOS)

Native iPhone app for the FairLie smart-mat system — the full product, not just the lab.

## App

- **Sign in / Create account** then **profile setup** (city, handicap, skill, bag)
- **Home** — strike score, start session, putting snapshot, Clubhouse banner
- **Practice** — Strike Lab (BLE mat, zero, heatmap, grades, simulator)
- **Play** — challenges and club battles
- **Progress** — saved sessions and score trend
- **Club** — bag, trophies, friends, leaderboards, foursomes, device
- **Profile & Settings** — bio, handicap, privacy, data export, delete account, sign out

Sign-in supports email/password and **Sign in with Apple**. Accounts and swing
history are stored on-device; deleting your account removes all of it immediately.

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
