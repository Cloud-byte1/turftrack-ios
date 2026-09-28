# fairLie — Canva Presentation Prompt

## Part A — How to use

Copy the entire fenced prompt in **Part B** below and paste it into Claude (or Claude in Canva, if available) with the instruction: **"Create a Canva presentation from this brief."** Canva Magic Design and Claude cannot always auto-build slides from text alone — the prompt asks Claude to deliver **(1)** a slide-by-slide outline you can turn into designs, and **(2)** copy-paste-ready Canva Magic Design prompts per slide where useful.

---

## Part B — The Claude prompt

````markdown
You are a product designer and pitch-deck writer for **fairLie**, a golf strike-training platform (hardware + iOS app + web lab). Create a **16–18 slide investor/product pitch deck** for Canva.

## Your deliverables

1. **Slide-by-slide outline** — for each slide: title, 3–5 bullets OR one key visual description, optional speaker notes, Canva layout hint (hero / split / grid / phone mockup / full-bleed photo).
2. **Canva Magic Design prompts** — one short, copy-paste prompt per slide (when Magic Design helps). Use fairLie brand colors and specify "clean product pitch, light mode, golf atmosphere."
3. **Optional 9:16 social cut** — after the deck, list which 5–6 slides to repurpose for a vertical social teaser.

**Do NOT invent features not described below.** Social/challenge data is catalog-driven demo content in v1.0 — present it as designed UI, not as live backend.

---

## Brand system

| Element | Spec |
| --- | --- |
| **Name** | fairLie (lowercase f, capital L) |
| **Tagline** | Train your strike. Own your game. |
| **App Store subtitle** | Golf strike & swing training |
| **Bundle ID** | com.fairlie.turftrack |

### Colors (use hex in all designs)

| Token | Hex | Use |
| --- | --- | --- |
| Green deep | `#0f5c38` / `#11623C` | Hero gradients, headers, icon gradient start |
| Green | `#1c9c5e` / `#1B9B5E` | Primary CTAs, accents, icon gradient end |
| Green dark | `#12613d` | Active session cards, secondary green surfaces |
| Gold | `#f5d433` / `#F4D232` | Swing-path accent, XP, highlights, coach cards |
| Cream | `#f5f5f5` / `#F7F5EF` | App / slide backgrounds |
| Paper | `#ffffff` | Cards |
| Ink | `#17211c` / `#14201A` | Headlines, body text |
| Muted | `#697570` | Secondary text |
| Eyebrow | `#7d8a82` | ALL-CAPS section labels (11px, tracked) |
| Profile beige | `#e8d4a8` | Avatar fills |
| Danger | `#d6453b` | End session, low grades |

### Typography

- Modern geometric sans — **Inter** or **SF Pro** feel
- Heavy display weight for big numbers (carry yards, strike scores)
- Bold headlines; eyebrow labels in small caps with letter-spacing
- Wordmark: "fair" in ink, "Lie" in green (#1B9B5E), capital L

### Icon / logo

- **App icon:** white golf ball on tee + single gold (#F4D232) swoosh arc on green diagonal gradient (#11623C → #1B9B5E). **No text on icon.**
- Full-bleed square, no rounded corners (iOS masks it)

### Visual rules

- Light mode only — cream backgrounds, white cards, soft green shadows
- Card corner radius ~**22px**; pill buttons fully rounded
- Green CTAs; gold for XP / coach / challenge highlights
- Golf-course atmosphere: subtle fairway textures, morning range light — **no purple AI clichés, no dark mode, no neon**
- Phone mockups on cream plates for UI slides
- Grade colors: A green, B light green, C gold, D orange-red, F dark red

---

## Product story

### Hardware

- **GolfMat** — pressure/FSR sensor mat (6 zones S1–S6: heel-to-toe grid) + swing detection
- **Optional XM125 radar** — separate ESP board for ball speed (USB in web lab; BLE packet on iPhone when wired to mat)
- Connection: **Bluetooth LE** (mat ESP); radar ESP on second COM in web Strike Lab

### Software

- **iOS companion** — SwiftUI app (TurfTrack target), portrait-only, iOS 16+
- **Strike Lab web** — browser lab for mat COM/BLE + radar USB (same workflow as app Practice tab)

### Core loop

**Start session → Connect mat → Zero sensors → Initialize swing → Strike → Grade A–F → Coach note → Session history**

Built-in **swing simulator** works offline — no mat required (critical for App Store review and demos).

### Positioning (App Store copy)

> fairLie turns your practice mat into a coach. Pair with GolfMat over Bluetooth — every strike measured instantly: live pressure heatmap, letter grade, 3-D swing path, club/ball speed, attack angle, club path. Build a practice habit with sessions, progress trends, and challenges. No mat yet? Full simulator shows grading and coaching before hardware.

**Keywords:** golf, swing, launch, monitor, impact, strike, practice, range, handicap, ball, tempo, coach

---

## App architecture

**5-tab bottom bar** (floating pill tab bar, white blur, green active icon):

| Tab | Label | Purpose |
| --- | --- | --- |
| 1 | Home | Dashboard, quick stats, start session |
| 2 | Practice | Strike Lab — full session workflow |
| 3 | Play | Challenges |
| 4 | Progress | Strike trend + session history |
| 5 | Club | Clubhouse — social, bag, trophies, device |

Overlays (not tabs): Login, Profile Setup, Profile sheet, Settings sheet, Legal (Privacy / Terms).

---

## Sample user data (use consistently: Carmi)

| Field | Value |
| --- | --- |
| Name | Carmi |
| Username | @carmi_golf |
| Email | carmi@fairlie.app |
| City | Miami, FL |
| Handicap | 12.4 |
| Strike score | 76 |
| Center strike | 54% |
| Clean contact | 54% / 68% |
| Level | Range Regular · Level 2 |
| Strike XP | 240 (1240 XP to Ball Striker) |
| Sessions | 48 |
| Streak | 12 day streak |
| Bio | Dialing in center contact one range session at a time. |
| Bag | Driver, 5 Wood, 7 Iron, Pitching Wedge, Sand Wedge |
| Best club | 7 Iron · 84 avg |
| Fix this next | Heel contact on irons |
| Putting | 8/12 made · 12 ft · line accuracy 82% |

### Sample swing (flush A-grade for hero slide)

- Carry **176 yds** · Ball **124 mph** · Club **85 mph** · Smash **1.46**
- Attack **-3.6°** · Path **-0.8°** · Grade **A** · Overall score **93**
- Impact: centered · H/C/T **22/56/22** · Radar **122.4 mph**

### Sample session (7 Iron practice)

- Today, 2:42 PM · 3 swings · Avg score **88** · Best carry **176 yds**
- Avg ball 116 · Best ball 124 · Avg club 82 · Smash 1.41 · Radar hits 67% · Attack -2.8° · Centered 33%

---

## Per-screen design inventory

### Login (`LoginView`)

- Green gradient hero: **fairLie** + tagline
- Card: Sign in / Create account toggle
- Email + password fields; green **Sign in** CTA
- **Sign in with Apple** (black pill)
- Footer: Privacy Policy · Terms of Use
- Cream background

### Profile setup (onboarding)

- Eyebrow: PROFILE SETUP · Headline: **Build your golfer card**
- Fields: Home course/city (Miami, FL), Handicap slider (12.4)
- Skill levels: Beginner · **Range Regular ✓** · Ball Striker · Shot Shaper
- My bag multi-select (5 clubs)
- CTA: **Enter the clubhouse**

### Home (`HomeView`)

- Header: avatar **C**, "Ready to dial in your strike?", name, **Mat off/on** pill
- Green gradient **Clubhouse** hero card → "Friends · leaderboards · your golf crew"
- 3 chips: **76** Strike score · **54%** Center · **68%** Clean
- Green **Start Session** button (red **End Session** when active)
- **PUTTING SNAPSHOT** card: 8/12 made · 12 ft · 82% line bar
- **Quick reads** insight cards (gold/green/blue tick): fix heel contact, active challenge, best club
- Photo tiles: Course prep · Practice Lab · Strike ref

### Practice / Strike Lab (`LabView`)

**Top:** fairLie brand mark · avatar · **12 day streak**

**Welcome:** date eyebrow · "Good afternoon, Carmi." · **＋ Start session** pill

**Active session card** (green dark): SESSION IN PROGRESS · 7 Iron practice · stats grid (swings, avg score, best yds, avg ball, smash, radar) · **Finish & save**

**5-step workflow bar:** Session → Connect → Zero → Initialize → Strike (numbered circles, green when done/active)

**Mat dock:** MAT ESP · FSR / SWING · status title · buttons: Mat BLE · Zero sensors · Initialize swing · Disconnect · Clear to zero · Test swing

**Radar dock:** RADAR ESP · XM125 · Connect radar / locked state

**Radar panel:** mph · mm · intra stats when locked (green deep gradient)

**Swing simulator:** sliders — Ball speed, Club speed, Attack angle, Swing path, Impact quality · Randomize · Simulate swing · Live track toggle

**Live monitor** (ink/dark card): S1–S6 sensor bars with peak highlight · peak · sensor · state

**Hero strike card** (green gradient): LAST STRIKE · **176** yds carry · club/ball/smash/attack/path/radar metrics · STRIKE LAB live chip

**Strike summary:** circular score ring (e.g. 93 Excellent) · 8-metric grid · impact label

**3D swing path:** SVG arc with gold dot · Idle/Live badge

**Strike grades:** Overall · Contact · Swing path · Attack — letter badges A–F with numeric scores

**Compare contact:** preset buttons — Perfect · Heel · Toe · Thin · Random

**Impact analysis:** club picker (Driver / 7 Iron / PW) · **LIVE PRESSURE MAP** 3×2 heat grid (HEEL | TOE labels) · impact row with ✓

**Coach's note** (gold-cream gradient card): title + paragraph coaching copy

**This session:** history rows with grade badge, note, score, yds, mph, smash, angles

### Progress (`ProgressViewTab` + `SessionsView`)

- Eyebrow PROGRESS · **Your strike trend**
- 3 cards: **78** avg score · **176** best yds · **48** sessions
- **SCORE HISTORY** sparkline bar chart (green/gold/orange bars)
- **YOUR ACTIVITY · All sessions** — rows: 7 Iron 88 · Driver 72 · PW 58 with best carry
- Session detail expand: 9-stat grid (avg score, best carry, avg/best ball, avg club, smash, radar hits, attack, centered)

### Play / Challenges (`ChallengesView`)

- **Challenges** · "Compete on skill, not just volume."
- Gold hero: YOUR TURN · Center Strike Streak · 6/20 shots remaining
- **Active:** Center Strike Streak (6/20, 1 golfer) · 7 Iron Club Battle (0/15, 4 golfers, 50 XP stake) · Ghost Mode (12/20)
- **Upcoming:** Fairway Finder (5/7, 8 golfers)
- **Challenge types grid:** Center Strike, Consistency, Club Battle, Friend Duel, Ghost Mode, Fairway Finder, Wedge Ladder, 9-Shot Matrix, Course Prep, Clubhouse Tournament
- CTAs: Create Challenge · Join with Code
- **Fair play** card: verified mat sessions · skill brackets

### Clubhouse (`ClubhouseView`)

- **CLUBHOUSE · Your crew**
- Profile head: Carmi · Range Regular Level 2 · HCP 12.4 · Strike 76 · XP ring **240**
- XP bar to Ball Striker · bio · @carmi_golf · Miami, FL
- **My Bag** grid (5 clubs)
- **Trophy Case:** 🏆 First Center Strike · 🏆 10 Clean Contacts · 🔒 No Fat Session · 🔒 7-Iron Mastery · 🔒 Ghost Slayer
- **Friends:** Jordan 91 · Priya 74 · Sam 68 · Devon 61 (with @handles and cities)
- **Leaderboard** toggle Friends / Clubhouse · verified/manual tags · YOU highlight · ranked by strike score
- **Clubhouse groups:** Weekend Foursome (4) · Range Regulars (12)
- **Device:** fairLie Smart Mat · Offline/Connected · Firmware 1.2.0 · Recalibrate
- Links: My profile · Settings & levels · Friends · Privacy & safety

### Profile & Settings (`ProfileView`)

**Profile:** @carmi_golf header · avatar · stats (48 Sessions, 128 Followers, 4 Following) · badges A-2, HCP 12.4 · tabs Activity / Stats / Clips · session activity feed

**Settings sections:**
- Profile (name, city, bio, handicap, Save)
- Preferences: Outdoor readability toggle · Notifications toggle
- Privacy & data: Privacy Policy · Terms · Export my data
- Support: Contact · Help centre
- Account: Sign in with Apple · Sign out · **Delete account** (danger) · v1.0.0

### Legal (`LegalView`)

- In-app Privacy Policy and Terms of Use (mirrored from fairlie.app)
- Effective date September 3, 2026

---

## Slide deck structure (16–18 slides)

For each slide, output: **Title · Bullets or visual · Speaker notes (optional) · Layout hint · Canva Magic Design prompt**

1. **Title / brand** — fairLie logo, tagline, golf mat + phone hero. *Layout: hero full-bleed.*
2. **Problem** — Range practice with no feedback: guessing contact, no grades, no progress loop. *Layout: split (frustrated golfer | empty stats).*
3. **Solution** — fairLie + GolfMat: hardware senses strike, app coaches instantly. *Layout: hero product shot.*
4. **Brand & visual system** — palette swatches, typography, icon, card style. *Layout: grid.*
5. **App architecture** — 5-tab diagram: Home · Practice · Play · Progress · Club. *Layout: phone mockup + callouts.*
6. **Auth & onboarding** — Login, Sign in with Apple, profile setup (city, HCP, skill, bag). *Layout: two phone mockups side by side.*
7. **Home screen** — dashboard chips, Clubhouse hero, quick reads, start session. *Layout: phone mockup.*
8. **Strike Lab overview** — 5-step workflow + session card. *Layout: split (workflow diagram | phone).*
9. **Live strike feedback** — heatmap, A–F grades, 176 yds hero metrics. *Layout: phone mockup close-up.*
10. **Sensors & radar** — S1–S6 FSR grid, live monitor, XM125 radar stats. *Layout: grid (mat diagram + radar panel).*
11. **Simulator & compare contact** — offline demo path; Perfect/Heel/Toe/Thin presets. *Layout: phone + bullet list.*
12. **Impact analysis & coach** — pressure map, H/C/T split, coach's note card. *Layout: split.*
13. **Progress / sessions** — sparkline trend, session history, detail stats. *Layout: phone mockup.*
14. **Play / challenges** — active challenges, types grid, fair play. *Layout: phone mockup.*
15. **Clubhouse** — friends, leaderboard, trophies, bag, XP. *Layout: phone mockup or grid of social cards.*
16. **Profile & settings** — activity feed, privacy, delete account. *Layout: two small phone frames.*
17. **Demo reel / hardware** — note: 83s auto-play demo exists; mat + BLE + optional radar; simulator for review. *Layout: video still or hardware photo + caption.*
18. **Roadmap / ask** — App Store readiness (Sign in with Apple, account deletion, privacy manifest, guest/sim path), v1.0 free, future Pro tier. *Layout: hero closing slide with CTA.*

---

## Canva instructions

- **Primary aspect:** 16:9 widescreen presentation
- **Also offer:** 9:16 social cut map (5–6 slides) from same content
- **Style:** Clean product pitch; photo or abstract golf-green textures; iPhone 15-style mockups for UI slides; generous whitespace
- **Export:** PDF for sharing; optional MP4 if Canva supports slide animation
- **Consistency:** Same cream background and green CTAs on every slide; fairLie wordmark bottom-right on UI slides
- **Do not show:** features absent from the inventory above (no subscription paywall in v1.0, no cloud sync claims beyond local device storage, no invented sensors beyond S1–S6 + XM125)

---

## Output format

```text
SLIDE 1: [Title]
Layout: [hint]
Bullets:
- ...
Visual: ...
Speaker notes: ...
Canva Magic Design prompt: "..."

[repeat for all slides]

SOCIAL CUT (9:16):
- Slide X → ...
```
````

---

## Part C — Appendix

### Brand palette (quick reference)

| Token | Hex | RGB (Theme.swift) |
| --- | --- | --- |
| Ink | `#17211c` | 0.09, 0.13, 0.11 |
| Muted | `#697570` | 0.41, 0.46, 0.44 |
| Eyebrow | `#7d8a82` | 0.49, 0.54, 0.51 |
| Green | `#1c9c5e` | 0.11, 0.61, 0.37 |
| Green dark | `#12613d` | 0.07, 0.38, 0.24 |
| Green deep | `#0f5c38` | 0.06, 0.36, 0.22 |
| Cream | `#f5f5f5` | 0.96, 0.96, 0.96 |
| Gold | `#f5d433` | 0.96, 0.83, 0.20 |
| Profile beige | `#e8d4a8` | 0.91, 0.83, 0.66 |
| Danger | `#d6453b` | 0.84, 0.27, 0.23 |

Alternate brand-doc hex values (logo / App Store): green deep `#11623C`, green `#1B9B5E`, gold `#F4D232`, cream `#F7F5EF`, ink `#14201A`.

### Screen checklist → iOS source files

| Screen | Swift file | Demo reel beat |
| --- | --- | --- |
| Login | `LoginView.swift` | Opening |
| Profile setup | `LoginView.swift` (onboarding) | ~7s |
| Home | `HomeView.swift` | ~9s |
| Strike Lab | `LabView.swift` + `LabComponents.swift` | ~14–52s |
| Progress | `ProgressViewTab` in `SessionsView.swift` | ~52s |
| Sessions list | `SessionsView.swift` | ~52s |
| Challenges | `ChallengesView.swift` in `ClubhouseView.swift` | ~58s |
| Clubhouse | `ClubhouseView.swift` | ~64s |
| Profile | `ProfileView.swift` | ~72s |
| Settings | `ProfileView.swift` (SettingsView) | ~72s |
| Legal | `LegalView.swift` | Linked from Login / Settings |
| Theme / colors | `Theme.swift` | All screens |
| Catalog data | `FairLieCatalog.swift` | Challenges, badges, friends, leaderboard |

### Assets & references

| Asset | Path |
| --- | --- |
| Demo video (83s webm) | [`demo/out/fairlie-demo.webm`](../demo/out/fairlie-demo.webm) |
| Demo source / shot list | [`demo/index.html`](../demo/index.html) |
| Logo & icon prompts | [`turftrack-ios/docs/brand/LOGO_PROMPT.md`](../../turftrack-ios/docs/brand/LOGO_PROMPT.md) |
| App Store positioning | [`turftrack-ios/docs/APP_STORE_LAUNCH.md`](../../turftrack-ios/docs/APP_STORE_LAUNCH.md) |
