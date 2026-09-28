# fairLie App Store launch checklist

This checklist covers the current iPhone app, bundle ID `com.fairlie.turftrack`, with a minimum deployment target of iOS 16.

## Public pages

GitHub Pages serves the public site from the `docs/` folder on the `main` branch.

| Page | URL | Status |
| --- | --- | --- |
| Marketing | https://cloud-byte1.github.io/turftrack-ios/ | Done via GitHub Pages |
| Privacy | https://cloud-byte1.github.io/turftrack-ios/privacy/ | Done via GitHub Pages |
| Terms | https://cloud-byte1.github.io/turftrack-ios/terms/ | Done via GitHub Pages |
| Support | https://cloud-byte1.github.io/turftrack-ios/support/ | Done via GitHub Pages |

Enter the marketing, privacy, and support URLs in App Store Connect exactly as shown. Keep these pages available after release.

## Reviewer access and hardware

Reviewer access is no longer blocked by sign-in. From the login screen, a reviewer can choose **Continue without an account** and use Home, Practice, Progress, the profile, the GolfMat flow, radar flow, and swing simulator. The Clubhouse requires an account, so a working demo account is still recommended if Apple should review its leaderboard, feed, challenges, and events.

The GolfMat and radar are not required for review because the built-in simulator exercises the practice flow. Simulated swings, examples, and test swings are clearly labeled **SIMULATED**. Attach a short video of the physical GolfMat and optional radar operating with the app if available.

## Accounts, storage, and privacy

- Email/password and Sign in with Apple accounts use Supabase Auth.
- Authentication tokens are stored in the iOS Keychain.
- Signed-in profiles, private practice sessions, Clubhouse posts, likes, RSVPs, and challenge progress are stored in Supabase.
- Guest profiles and sessions are stored only on the iPhone in UserDefaults and are never uploaded.
- Sessions containing simulated swings remain on the iPhone and are never uploaded or ranked.
- Settings includes immediate account deletion for the Supabase user and all owned data.
- Guests can erase guest data in Settings.
- The app has no analytics, ads, cross-app tracking, or ATT prompt.

The Clubhouse feed supports Report, Hide, Block author, and deletion of a golfer's own posts. These controls and the public support email address should be mentioned when answering the user-generated-content questions.

## Bluetooth and measurement wording

Bluetooth is used only for the GolfMat ESP32 pressure/FSR mat and the optional second ESP32 with an Acconeer XM125 radar. The app automatically reconnects to the last device after a dropped connection.

Store metadata and screenshots must describe carry distance, club speed, and attack angle as **estimates** derived from mat sensors. Ball speed is **measured** only when a radar reading is merged; otherwise it is estimated. Do not advertise smash factor, putting tracking, followers, or video clips.

## App Privacy questionnaire

Use the following answers in App Store Connect. Each collected type is linked to identity, used only for App Functionality, and not used for tracking.

| Data type | Collected | Linked to identity | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| Name | Yes | Yes | No | App Functionality |
| Email Address | Yes | Yes | No | App Functionality |
| User ID | Yes | Yes | No | App Functionality |
| Fitness (practice/swing data) | Yes | Yes | No | App Functionality |
| Other User Content (feed posts) | Yes | Yes | No | App Functionality |

Answer **No** when asked whether fairLie or its third-party partners use data for tracking. Supabase is the database and authentication processor; Apple processes Sign in with Apple. Review the answers again whenever data collection changes.

## Signing and capabilities

- Select the Apple Developer Team in Xcode under **Signing & Capabilities**. No Team ID is committed to the repository.
- Confirm the bundle ID is `com.fairlie.turftrack`.
- Enable Sign in with Apple for the App ID and target.
- Archive with a current App Store-supported Xcode and SDK.
- Test the archive on a physical iPhone running the oldest supported major version where practical.
- Increment the build number for every upload.

## App Store metadata checks

- Support URL: `https://cloud-byte1.github.io/turftrack-ios/support/`
- Marketing URL: `https://cloud-byte1.github.io/turftrack-ios/`
- Privacy Policy URL: `https://cloud-byte1.github.io/turftrack-ios/privacy/`
- Terms URL where requested: `https://cloud-byte1.github.io/turftrack-ios/terms/`
- Support email: `support@fairlie.app`
- State that the app requires iOS 16 or later.
- Use screenshots of current functionality and label simulated results clearly.
- Answer the age-rating questionnaire to disclose user-generated Clubhouse content.

## App Review notes template

```text
ABOUT THIS APP
fairLie is an iPhone golf-practice app for iOS 16 or later. It connects over
Bluetooth LE to a GolfMat pressure/FSR mat and optionally to a separate ESP32
with an Acconeer XM125 radar.

REVIEWING WITHOUT AN ACCOUNT OR HARDWARE
On the login screen, tap "Continue without an account." Guest mode provides Home,
Practice, Progress, the profile, and the swing simulator. Open Practice and use the
swing simulator, examples, or test swing. These results are clearly labeled
SIMULATED. Hardware is not required to review the practice flow.

CLUBHOUSE
The leaderboard, feed, challenges, and events require an account. Use the demo
account below to review these features. Feed posts support Report, Hide, Block
author, and deletion of the user's own posts.

SIGN-IN AND DELETION
The app supports email/password and Sign in with Apple. Account deletion is at
Settings > Delete account and immediately deletes the Supabase Auth user and all
data owned by that account. Guests can erase guest data in Settings.

BLUETOOTH AND MEASUREMENTS
Bluetooth is used only for the GolfMat and optional radar ESP32. Carry distance,
club speed, and attack angle are estimates. Ball speed is measured only when a
radar reading is merged; otherwise it is estimated.

IN-APP PURCHASES
None.

DEMO ACCOUNT FOR CLUBHOUSE
Email: <enter working demo email>
Password: <enter working demo password>
```

## Before submission

1. Enable GitHub Pages for `main` and `/docs`, then open all four public URLs.
2. Verify guest mode on a fresh install and erase guest data in Settings.
3. Verify email/password and Sign in with Apple on a physical device.
4. Verify Settings account deletion with a disposable Supabase account.
5. Verify Report, Hide, Block, and own-post deletion in the Clubhouse.
6. Test GolfMat connection, optional radar connection, and automatic reconnection.
7. Confirm simulated sessions remain local and do not appear in rankings.
8. Complete the privacy and age-rating questionnaires.
9. Add current screenshots, review notes, and a working Clubhouse demo account.
10. Upload to TestFlight and test the exact build before submitting it for review.
