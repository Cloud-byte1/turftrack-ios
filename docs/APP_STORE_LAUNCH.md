# fairLie — App Store launch requirements

Everything needed to get `com.fairlie.turftrack` from this repo onto the App Store.
Status column meanings: **Done** = handled in this repo · **You** = needs an action
only the account holder can take · **Todo** = still needs producing.

---

## 0. The two things most likely to get fairLie rejected

Read these before anything else. They are specific to this app, not generic advice.

### 0.1 App Review cannot use your hardware

fairLie's core value is live data from a GolfMat over Bluetooth. Reviewers sit at a
desk with no mat, so every hardware-gated screen looks broken to them. That is the
classic Guideline 2.1 "app is incomplete" rejection for accessory apps.

Mitigation, in order of importance:

1. **The built-in simulator must be reachable without hardware.** `SwingSimulator`
   and the Practice tab presets already generate full swings offline. Make sure a
   reviewer can find it in under 30 seconds from launch, with no "Connect a mat"
   dead end in the way.
2. **Say so in App Review Notes** (template in §6 below), including exactly which
   button to tap to see simulated data.
3. **Attach a demo video** of the real mat in action in App Store Connect →
   App Review Information → Attachment. This is the single most effective way to
   pass review for a hardware accessory app.

### 0.2 The app is behind a sign-in wall

Guideline 2.1 requires working demo credentials for any login-gated app. Accounts
in `AuthStore` are stored per-device in `UserDefaults`, so an account you create on
your phone does **not** exist on the reviewer's device.

You must do one of these before submitting:

- **Recommended:** let the app be browsed without an account — add a "Look around
  first" / guest button on `LoginView` that signs in a local demo profile. Apps that
  gate non-account-specific content behind registration violate 5.1.1(i) anyway.
- Or ship a hardcoded reviewer account (e.g. `review@fairlie.app` / `fairlie2026`)
  that `AuthStore.load()` seeds on first launch, and put those credentials in the
  Demo Account fields.

Either way, fill in App Review Information → Sign-In Required with credentials that
actually work on a fresh install.

---

## 1. Accounts & legal

| # | Requirement | Status | Notes |
| --- | --- | --- | --- |
| 1.1 | Apple Developer Program enrollment, $99/year | **You** | Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/). Allow 24–48 h for approval, sometimes up to 2 weeks for organizations. |
| 1.2 | Two-factor authentication on the Apple ID | **You** | Must be active *before* enrolling. Settings → your name → Sign-In & Security → Two-Factor Authentication. |
| 1.3 | D-U-N-S number | **You** | Only for organization enrollment. Free lookup/request at [developer.apple.com/enroll/duns-lookup](https://developer.apple.com/enroll/duns-lookup/); issuance takes up to 5 business days. **Individual enrollment needs no D-U-N-S** and publishes under your legal name — pick organization only if you want the seller shown as a company. |
| 1.4 | Publicly hosted Privacy Policy URL | **Todo** | Copy is written and ready at `docs/legal/privacy-policy.md`. Host it at `https://fairlie.app/privacy` and enter that URL in App Store Connect. Must stay reachable for the life of the app — a 404 here is an instant rejection. |
| 1.5 | Terms of Use | **Todo** | Copy ready at `docs/legal/terms-of-use.md` → host at `https://fairlie.app/terms`. Optional for a free app with no purchases, but the app already links to it, so it must resolve. |
| 1.6 | Tax and banking information | **N/A → You** | Only required once you charge money. Free app with no IAP: skip. Add later in App Store Connect → Business. |
| 1.7 | Paid Apps Agreement | **N/A → You** | Same as above — only needed when you monetize. |

Both policy documents are also **mirrored inside the app** (`LegalView.swift`), so
they render offline and during review even if the website is mid-deploy.

---

## 2. Technical

| # | Requirement | Status | Notes |
| --- | --- | --- | --- |
| 2.1 | Built with Xcode 26+, iOS 26 SDK | **Done** | `SDKROOT = iphoneos` builds against whichever SDK is installed, so simply archiving in Xcode 26 satisfies this. Verify with `xcodebuild -version`. |
| 2.2 | Deployment target | **Done** | `IPHONEOS_DEPLOYMENT_TARGET = 16.0`. This is the *minimum* OS you support and is unrelated to the SDK rule — keeping it low widens your audience. |
| 2.3 | 64-bit architecture | **Done** | iOS device builds are arm64-only; `ARCHS` is left at the default `$(ARCHS_STANDARD)`. Nothing to do. |
| 2.4 | App completeness — no placeholders, no broken links, no lorem ipsum | **Partial** | See the audit in §2b. This is the highest-risk item after the hardware problem. |
| 2.5 | In-app purchases via StoreKit only | **N/A** | fairLie 1.0 ships free with no purchases and no external payment links. If you later sell a Pro tier you must use StoreKit **and** add a Restore Purchases button — external payment links are forbidden. |
| 2.6 | Sign in with Apple | **Done** | `SignInWithAppleButton` in `LoginView.swift`, handled by `AuthStore.handleAppleSignIn`. Requires the Sign in with Apple capability on the App ID — see §2c. |
| 2.7 | In-app account deletion | **Done** | Settings → Delete account → `DeleteAccountView`, with a typed `DELETE` confirmation and a data-export option first. Calls `AuthStore.deleteAccount()`, which removes the account record and all user-scoped keys. |
| 2.8 | Privacy manifest | **Done** | `TurfTrack/PrivacyInfo.xcprivacy` declares no tracking, the five collected data types, and the `UserDefaults` required-reason API (`CA92.1`). |
| 2.9 | Bluetooth usage strings | **Done** | `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` and `...PeripheralUsageDescription` now name fairLie and state that Bluetooth is only used for the mat. |
| 2.10 | Encryption export compliance | **Done** | `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, which is correct for fairLie — it uses no encryption beyond OS-provided HTTPS — and stops the export-compliance question on every upload. |
| 2.11 | Launch screen | **Done** | `INFOPLIST_KEY_UILaunchScreen_Generation = YES`. |
| 2.12 | Orientation | **Done** | Portrait only, declared in build settings. If you submit for iPad you must also support iPad layouts properly. |
| 2.13 | Crash-free on launch | **You** | Test on a real device, not just the simulator, on the lowest OS you claim (iOS 16). CoreBluetooth behaves differently on device. |

### 2b. Completeness audit — placeholder content to remove

App Review reads your UI. These are real strings and behaviours in the current code
that read as unfinished or as fake data presented as real:

- `FairLieCatalog` supplies **mock friends, leaderboards, badges, and challenges.**
  Static fake social data is a Guideline 2.1 risk. Either label these sections
  clearly as previews/examples, or hide the Clubhouse social features and the Play
  tab's leaderboards until they are backed by something real.
- `AuthStore.apply()` contains a **special case for the name "carmi"** that swaps in
  the `.sample` profile with pre-filled stats. Remove it — it's a development
  shortcut that hands one user fabricated history.
- `FairLieUser.sample` is used as the signed-out placeholder. Confirm none of its
  invented stats ever surface to a real new user.
- The Settings **"Outdoor readability"** and **"Notifications"** toggles are local
  `@State` only: they reset on dismiss and change nothing. Wire them up or remove
  them. Non-functional controls are a documented rejection reason.
- `AppConfig` points at `fairlie.app/support`, `/privacy`, `/terms`. **Every one of
  those must return a real page**, not a parked domain.

### 2c. Capabilities and signing

In the Apple Developer portal, on the `com.fairlie.turftrack` App ID, enable:

- **Sign in with Apple** — mandatory, the entitlement file already requests it
  (`TurfTrack/TurfTrack.entitlements`, `com.apple.developer.applesignin = Default`).

Then in Xcode → Signing & Capabilities: select your team, let Xcode manage signing,
and confirm Sign in with Apple appears in the capabilities list. If the entitlement
is in the file but not on the App ID, the archive upload fails.

---

## 3. Metadata & App Store Connect assets

### 3.1 App information

| Field | Value | Limit |
| --- | --- | --- |
| App name | `fairLie` | 30 chars |
| Subtitle | `Golf strike & swing training` | 30 chars — currently 28 |
| Bundle ID | `com.fairlie.turftrack` | Must match Xcode exactly; **cannot be changed after first submission** |
| SKU | `FAIRLIE-IOS-001` | Your internal ID, never shown publicly, any unique string |
| Primary category | Sports | |
| Secondary category | Health & Fitness | |
| Primary language | English (U.S.) | |
| Copyright | `2026 fairLie` | |

Consider renaming the Xcode target/bundle from `turftrack` to `fairlie` **now** —
the bundle ID is permanent once submitted, and shipping a fairLie app under a
TurfTrack identifier is a permanent inconsistency.

### 3.2 App icon

**Done.** 1024×1024 opaque PNG, no alpha, no rounded corners, at
`TurfTrack/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Xcode derives every
smaller size. Prompts for regenerating it are in `docs/brand/LOGO_PROMPT.md`.

### 3.3 Screenshots

**Todo.** Modern App Store Connect requires only **one** iPhone size, which then
scales to the rest:

| Device class | Required size | Required? |
| --- | --- | --- |
| iPhone 6.9" (16 Pro Max / 15 Pro Max) | 1320 × 2868 or 1290 × 2796 | **Yes** — this set is mandatory |
| iPhone 6.5" / 5.5" | 1242 × 2688 / 1242 × 2208 | Only if you upload them separately |
| iPad 13" | 2064 × 2752 | Only if you ship an iPad build |

Rules: up to 10 per size, minimum 1, real UI only (no mocked-up screens showing
features that don't exist), no device frames with rounded corners baked in, RGB, no
alpha channel.

Suggested set of 5, in order:

1. **Practice / Strike Lab** with a live heatmap and a visible letter grade
2. **Swing path 3-D view** with attack angle and club path annotated
3. **Home** with the session summary and quick insights
4. **Progress** showing session history trends
5. **Clubhouse** — only if the social data is real by launch

Capture on a 6.9" simulator (`⌘S` saves at the exact required resolution).

### 3.4 Store links

| Field | Value | Required? |
| --- | --- | --- |
| Support URL | `https://fairlie.app/support` | **Mandatory** — must be live and offer a way to contact you |
| Marketing URL | `https://fairlie.app` | Optional |
| Privacy Policy URL | `https://fairlie.app/privacy` | **Mandatory** |

The support page needs at minimum a working contact address and ideally a short FAQ
covering mat pairing and calibration.

### 3.5 Description, keywords, promo text

**Todo.** Draft copy:

**Promotional text** (170 chars, editable without a new build):

> Every swing, graded. Pair your GolfMat and see exactly where you struck the ball,
> how hard, and what to fix next.

**Description** (4000 chars):

> fairLie turns your practice mat into a coach.
>
> Pair fairLie with your GolfMat over Bluetooth and every strike is measured the
> instant it happens. A live pressure heatmap shows exactly where on the face you
> made contact. A letter grade tells you how clean it was. And a reconstructed 3-D
> swing path shows the attack angle and club path that produced it.
>
> TRAIN WITH REAL FEEDBACK
> • Live strike heatmap that stays dark until impact, then flashes with strike quality
> • A-through-F grading on every swing so progress is obvious
> • Club speed, ball speed, attack angle, and club path per shot
> • 3-D swing path reconstruction you can rotate and inspect
>
> BUILD A PRACTICE HABIT
> • Sessions that summarize consistency, best strike, and trends
> • Progress tracking across every session you save
> • Challenges to keep range time focused
>
> NO MAT YET?
> Explore the full app with the built-in swing simulator — generate realistic swings
> and see exactly how the grading and coaching work before you connect hardware.
>
> fairLie stores your profile and swing history on your device. We don't track you
> across other apps and we don't sell your data.

**Keywords** (100 chars total, comma-separated, no spaces, don't repeat the app name
or your categories):

> golf,swing,launch,monitor,impact,strike,practice,range,handicap,ball,tempo,coach

### 3.6 Age rating questionnaire

Answer **None / No** to violence, sexual content, profanity, horror, gambling,
simulated gambling, contests, and drugs. The two that need care:

- **Unrestricted web access** — No (the app opens only your own vetted links).
- **User-generated content / social features** — the Clubhouse and profile bio are
  user content. If you ship them, answer Yes, which raises the rating and obliges
  you to provide content filtering, reporting, blocking, and a published contact for
  moderation (Guideline 1.2). **If the social features stay mocked for 1.0, remove
  them from the build and answer No.** That is much simpler for a first release.

Expected result with social features removed: **4+**.

### 3.7 App Privacy (the "nutrition label")

This is filled out in App Store Connect and must match `PrivacyInfo.xcprivacy`:

| Data type | Collected | Linked to user | Used for tracking | Purpose |
| --- | --- | --- | --- | --- |
| Name | Yes | Yes | No | App Functionality |
| Email Address | Yes | Yes | No | App Functionality |
| User ID | Yes | Yes | No | App Functionality |
| Fitness (swing/sport data) | Yes | Yes | No | App Functionality |
| Other User Content (bio) | Yes | Yes | No | App Functionality |

Everything else: **Not Collected.** No identifiers for advertising, no location, no
contacts, no diagnostics (unless you add analytics later — then update both places).

Answer **No** to "Do you or your third-party partners use data for tracking?" so the
App Tracking Transparency prompt is never required.

---

## 4. Build settings still to change

Concrete edits, all in the Xcode target's build settings:

Already applied in `project.pbxproj` for both Debug and Release:

```
CODE_SIGN_ENTITLEMENTS = TurfTrack/TurfTrack.entitlements
INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO
INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription = "fairLie connects to your GolfMat…"
INFOPLIST_KEY_NSBluetoothPeripheralUsageDescription = "fairLie connects to your GolfMat…"
```

The one thing left, which only you can supply:

```
DEVELOPMENT_TEAM = <your 10-character Team ID>
```

Set it by opening the project in Xcode and picking your team under Signing &
Capabilities — that writes the value into both configurations.

Version numbers are at `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION = 1`.
`CURRENT_PROJECT_VERSION` must increase on every upload, even for a rejected build.

---

## 5. Submission sequence

1. Enroll in the Developer Program; confirm 2FA. (§1.1–1.3)
2. Deploy `fairlie.app` with live `/privacy`, `/terms`, and `/support` pages. (§1.4)
3. Enable Sign in with Apple on the App ID; set your team in Xcode. (§2c)
4. Clear the placeholder audit in §2b.
5. Solve reviewer access — guest mode or a seeded demo account. (§0.2)
6. Apply the build settings in §4; test on a physical iPhone with a real mat.
7. App Store Connect → create the app record with the §3.1 values.
8. Xcode → Product → Archive → Distribute App → App Store Connect → Upload.
9. Wait for processing (10–60 min), then complete Age Rating and App Privacy.
10. Attach screenshots, description, keywords, and the App Review notes from §6.
11. Add a **demo video of the mat** as a review attachment. (§0.1)
12. Submit. Expect 24–48 h for a first review, and budget for one rejection round.

---

## 6. App Review notes template

Paste into App Store Connect → App Review Information → Notes:

```
ABOUT THIS APP
fairLie is a companion app for the GolfMat, a Bluetooth LE golf practice mat that
measures where and how hard a golf ball is struck.

TESTING WITHOUT THE HARDWARE
The mat is not required to review the app. A full swing simulator is built in:

1. Sign in with the demo credentials below (or tap "Look around first").
2. Open the Practice tab.
3. Tap "Simulate swing" and choose any preset.
4. Simulated swings flow through the identical pipeline as real ones — heatmap,
   letter grade, 3-D swing path, and session history all populate.

Every screen except the Bluetooth connection banner is fully functional offline.

A video of the physical mat driving the app in real time is attached.

BLUETOOTH
Bluetooth is used only to connect to the GolfMat accessory and receive strike
measurements. It is not used for location, ranging, or beacon scanning.

ACCOUNTS
Accounts are stored locally on device. Sign in with Apple is supported. Account
deletion is at Settings -> Delete account and removes all data immediately.

IN-APP PURCHASES
None in this version.

DEMO ACCOUNT
Email: review@fairlie.app
Password: <fill in>
```

---

## 7. Post-launch

- **TestFlight first.** Push the exact archive to internal testers before submitting
  for review; internal TestFlight needs no review and catches signing and
  entitlement problems in minutes.
- **Version bumps.** `MARKETING_VERSION` for user-visible releases,
  `CURRENT_PROJECT_VERSION` on every single upload.
- **Keep the URLs alive.** A dead Privacy Policy or Support URL can get a shipped
  app removed, not just rejected.
- **If you add a Pro tier:** StoreKit only, a visible Restore Purchases button,
  price and renewal terms shown before purchase, and a link to Apple's standard EULA
  (already in `AppConfig.appleStandardEULAURL`).
