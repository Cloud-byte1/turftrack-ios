---
layout: default
title: fairLie Privacy Policy
permalink: /privacy/
---

# fairLie Privacy Policy

**Effective September 28, 2026**

This is the canonical policy at [https://cloud-byte1.github.io/turftrack-ios/privacy/](https://cloud-byte1.github.io/turftrack-ios/privacy/).

## Information we collect

If you create an account, fairLie collects the account information you provide, including your email address and profile information such as display name, username, and handicap. We store your practice sessions, Clubhouse posts, likes, event RSVPs, and challenge progress. Practice data includes sensor readings, strike results, derived training estimates, selected club, and session dates and times.

If you use **Continue without an account**, fairLie stores your guest profile and guest sessions only on your iPhone in UserDefaults. Guest data is never uploaded to Supabase. You do not need to provide an email address in guest mode.

Simulated swings, examples, and test swings are labeled **SIMULATED**. Any session containing them stays on the iPhone and is never uploaded or ranked, whether you are a guest or signed in.

## Where information is stored

For signed-in golfers, Supabase provides authentication and cloud database hosting. Account tokens are stored in the iOS Keychain. Your profile, private practice sessions, posts, likes, RSVPs, and challenge progress are stored in Supabase. Practice sessions are private to your account.

Guest profiles, guest sessions, and every session containing simulated swings are stored only on the iPhone. Removing the app may delete this on-device data.

## Clubhouse information

The Clubhouse is available only to signed-in golfers. Your display name, username, handicap, streak, and average strike score appear on its leaderboard. Posts you submit to the Clubhouse feed are visible to other signed-in golfers. You can report or hide posts, block an author, and delete your own posts.

## Bluetooth and sensor data

fairLie uses Bluetooth only to discover, connect to, and exchange data with the GolfMat ESP32 pressure/FSR mat and the optional second ESP32 with an Acconeer XM125 radar. Bluetooth is not used for advertising, location tracking, nearby-person detection, or beacons. The app automatically attempts to reconnect to the last device after a dropped connection.

Carry distance, club speed, and attack angle are estimates derived from mat sensors. Ball speed is measured only when a radar reading is merged with a strike; otherwise it is estimated.

## Sign in with Apple

If you choose Sign in with Apple, Apple provides an app-specific user identifier and the name and email information you choose to share. If you use Hide My Email, fairLie receives Apple's relay email address. We use this information to create and authenticate your account. Apple processes information under its own privacy policy.

## Tracking, analytics, and advertising

fairLie has no analytics or advertising SDKs, does not show ads, does not track you across other companies' apps or websites, and does not request App Tracking Transparency permission. We do not sell personal information.

## Retention and deletion

Account data is kept until you delete the relevant content or delete your account. You can delete your own Clubhouse posts. Choosing **Delete account** in Settings immediately deletes your Supabase Auth user and all data you own, including your profile, practice sessions, posts, likes, RSVPs, and challenge progress. If you use Sign in with Apple, you confirm with Apple and fairLie revokes its Sign in with Apple tokens before the account is deleted. This cannot be undone.

Guest data is kept on the iPhone until you erase guest data in Settings or delete the app. Sessions containing simulated swings are on-device data and follow the same on-device retention behavior.

## Access and export

Signed-in golfers can use the data export option in Settings to export their data. Guests can review their locally stored profile and session history in the app. For help with an access or export request, email [support@fairlie.app](mailto:support@fairlie.app).

## Service providers

Supabase processes account and cloud data for database and authentication hosting. Apple processes Sign in with Apple information when you use that sign-in method. We do not use advertising or analytics providers.

## Children

fairLie is not directed to children under 13, and we do not knowingly collect personal information from children under 13. If you believe a child has provided information, contact us so we can delete it.

## Changes

We may update this policy when our practices change. We will update the effective date on this page.

## Contact

For privacy questions or requests, email [support@fairlie.app](mailto:support@fairlie.app).
