# fairLie (iOS)

fairLie is a native SwiftUI iPhone app for iOS 16 and later. Its bundle ID is `com.fairlie.turftrack`.

## App

- **Home** - practice summary, strike score, progress, and quick access to start a session
- **Practice** - GolfMat pressure/FSR feedback, optional radar ball speed, and a clearly labeled swing simulator
- **Progress** - saved sessions and trends
- **Profile and Settings** - profile details, privacy, data export, guest-data erasure, account deletion, and sign out
- **Clubhouse** - leaderboard, feed, challenges, and events for signed-in golfers

The login screen supports email/password, Sign in with Apple, and **Continue without an account**. Guests can use Home, Practice, Progress, the simulator, and their profile. Guest profiles and sessions are stored only on that iPhone in UserDefaults and are never uploaded. The Clubhouse requires an account.

Simulated swings, examples, and test swings are labeled **SIMULATED**. Any session containing them stays on the iPhone and is never uploaded or ranked.

## Hardware and measurements

- The GolfMat ESP32 pressure/FSR mat advertises as `GolfMat`.
- The optional second ESP32 with an Acconeer XM125 radar advertises as `GolfMatRadar`.
- Bluetooth Low Energy is used only to connect to these two devices.
- The app automatically reconnects to the last device if the connection drops.

Carry distance, club speed, and attack angle are estimates derived from mat sensor readings. Ball speed is measured only when a radar reading is merged with the strike; without radar it is an estimate. fairLie does not provide smash factor, putting tracking, followers, or video clips.

## Accounts and Supabase

Signed-in accounts use Supabase Auth with email/password or Sign in with Apple. Tokens are stored in the iOS Keychain. Supabase stores the signed-in profile, private practice sessions, Clubhouse posts, likes, RSVPs, and challenge progress.

The Clubhouse leaderboard shows display name, username, handicap, streak, and average strike score. Feed posts are visible to other signed-in golfers. Users can Report, Hide, or Block on posts and can delete their own posts.

Settings includes account deletion, which immediately deletes the Supabase Auth user and all data they own. The app has no analytics, advertising, tracking, or App Tracking Transparency prompt.

Supabase SQL files are under [`docs/supabase`](docs/supabase). Never put a Supabase `service_role` key in the app.

## Open and run

1. Open `TurfTrack.xcodeproj` on a Mac with Xcode.
2. Choose your Apple Developer Team in Xcode under **Signing & Capabilities**. No Team ID is committed to the repository.
3. Enable Sign in with Apple for the `com.fairlie.turftrack` App ID and target.
4. Run on an iPhone with iOS 16 or later.

Hardware is optional for exploring the app because guest mode and the built-in simulator are available from the login and Practice flows.

## Public pages

- [Marketing site](https://cloud-byte1.github.io/turftrack-ios/)
- [Privacy Policy](https://cloud-byte1.github.io/turftrack-ios/privacy/)
- [Terms of Use](https://cloud-byte1.github.io/turftrack-ios/terms/)
- [Support](https://cloud-byte1.github.io/turftrack-ios/support/)

See [`docs/APP_STORE_LAUNCH.md`](docs/APP_STORE_LAUNCH.md) for the submission checklist.
