# fairLie demo reel

A self-contained iPhone-framed tour of the fairLie app, scripted to auto-play
and recorded to a video you can drop into CapCut (or Premiere).

> **Not for the App Store.** Apple requires app-preview videos to be captured on a
> real iPhone. This reel is for marketing, investors, and social. See
> `../docs/APP_STORE_LAUNCH.md` §0 once you have a Mac.

## What's in the box

| File | What it is |
| --- | --- |
| `index.html` | Full app tour — Login, Profile Setup, Home, Practice (Strike Lab), Progress, Play (Challenges), Club (Clubhouse), Profile & Settings sheets |
| `record.mjs` | Headless Chromium recorder → `out/fairlie-demo.webm` (and `.mp4` if ffmpeg is installed) |
| `preview.mjs` | Grabs stills at key timestamps into `out/frames/` so you can eyeball the design |

The UI is painted to match `turftrack-ios` (`Theme.swift` palette, Carmi's sample
profile, the real challenge / leaderboard / badge catalog).

### Screens covered in the reel

| Beat | iOS surface |
| --- | --- |
| Opening | `LoginView` — sign in, Sign in with Apple, privacy footer |
| ~7s | `ProfileSetupView` — city, handicap, skill, bag pickers |
| ~9s | `HomeView` — avatar, mat pill, Clubhouse hero, strike chips, putting snapshot, quick reads |
| ~14–52s | `LabView` — full Strike Lab (mat connect, zero, radar, five graded swings) |
| ~52s | `ProgressViewTab` + `SessionsView` — trend cards, sparkline, session history |
| ~58s | `ChallengesView` — active/upcoming challenges, types, fair-play card |
| ~64s | `ClubhouseView` — profile, bag, trophies, friends, leaderboard toggle, foursomes, device |
| ~72s | `ProfileView` + `SettingsView` — activity feed, preferences, privacy, account |
| End | Home + “fairLie — train your strike” |

## Record it

```powershell
cd demo
npm run setup     # once — installs Playwright + Chromium
npm run record    # writes out/fairlie-demo.webm (~83s, 860×1864)
```

CapCut imports `.webm` natively. For an `.mp4` (preferred by Premiere and most
hosts), install ffmpeg and re-run:

```powershell
winget install Gyan.FFmpeg
# restart the terminal so ffmpeg is on PATH, then:
npm run record
```

Preview the stills any time with `npm run preview`.

Open `index.html` in a browser (or `npx serve .`) to watch the tour live, without
recording. Append `?manual=1` to the URL to pause autoplay.

## CapCut recipe (marketing cut)

1. **New project → 9:16** (TikTok / Reels / Stories). CapCut's "Auto cut" or
   Premiere's "Social Media" preset both work.
2. **Import** `out/fairlie-demo.webm` (or the `.mp4`). Drop it on the timeline.
3. **Phone frame (optional but looks finished):**
   - CapCut → Overlay → add a transparent iPhone bezel PNG, or
   - Effects → search "Phone Frame" / "Device Frame".
   - Scale the recording so the UI sits inside the screen area. The recording is
     already phone-shaped, so a thin bezel is enough — don't double up the
     status bar.
4. **Captions are already baked in.** If you want bigger / branded ones, mute
   the on-screen pills (Effects → Opacity → 0 on those moments) and add CapCut
   Auto Captions from a voiceover instead.
5. **Music:** CapCut → Audio → Sounds. Keep it under the captions; App Store
   previews autoplay muted, but marketing cuts need a bed. Prefer royalty-free.
6. **End card (last 2s):** freeze the final frame, overlay the fairLie wordmark
   and "Coming soon" / App Store badge placeholder.
7. **Export:** 1080×1920, 30 fps, High quality. CapCut's default H.264 is fine.

### Suggested 30-second social cut

Trim the ~83s master down to this:

| Time | Beat |
| --- | --- |
| 0–3s | Home with the "Your strike, tracked every session" caption |
| 3–8s | Connect + calibrate the mat |
| 8–18s | The five swings — hold on the flush-center **A** |
| 18–22s | Progress sparkline |
| 22–26s | Challenges |
| 26–30s | Clubhouse leaderboard + end card |

## App Store preview (later, needs a Mac)

1. Build and run `turftrack-ios` on a real iPhone from Xcode.
2. Plug the phone into the Mac → QuickTime Player → File → New Movie Recording →
   pick the iPhone as the camera.
3. Walk through the same beats as this reel (the captions in `index.html` are
   a shot list), stay under 30 seconds, export H.264 at the device's native
   resolution, upload to App Store Connect.

## Pitch / Canva

For a ready-to-paste Claude prompt that turns the full fairLie product design into a 16–18 slide Canva pitch deck (brand system, every screen, sample data, Magic Design prompts per slide), see [`../docs/FAIRLIE_CANVA_PRESENTATION_PROMPT.md`](../docs/FAIRLIE_CANVA_PRESENTATION_PROMPT.md). Copy the fenced block in Part B into Claude with “create a Canva presentation.”

## Regenerating after UI changes

Edit `index.html`, then:

```powershell
npm run preview   # check the frames first
npm run record    # re-cut the video
```

The timeline lives in the `TL` array near the bottom of `index.html`. Times are
milliseconds from start; `window.__demoDone` flips when the reel ends so the
recorder knows when to stop.
