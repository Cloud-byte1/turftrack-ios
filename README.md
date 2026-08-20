# Strike Lab (FairLie iOS)

Native iPhone app for the FairLie / GolfMat system — the full Strike Lab UI:

- **Lab** — connect GolfMat over BLE, zero sensors, initialize a swing, strike heatmap, grades A–F, simulator, club-head path
- **Sessions** — save practice sessions with carry, ball/club speed, smash, radar hit rate
- **Progress** — score trend across saved sessions

## Requirements

- Mac with **Xcode 15+**
- iPhone on **iOS 16+**
- Apple ID (free signing works for your own device)
- Optional: GolfMat firmware advertising as `GolfMat` (service `0xAB12`, notify `0xAB13`)

## Open & run

1. Clone this repo on a Mac
2. Open `TurfTrack.xcodeproj` in Xcode
3. Select your Team under **Signing & Capabilities**
4. Plug in an iPhone, pick it as the run destination
5. Build & run (allow Bluetooth on first launch)

## App flow

1. **Start new session**
2. **Mat BLE** — pair GolfMat
3. **Zero sensors** (keep the mat still)
4. **Initialize swing** — pads stay at 0 until a real strike (`impact_quality ≥ 35`)
5. Strike paints the heat map and letter grades; finish the session to save it

No hardware? Use **Randomize / Simulate swing** or the contact examples (Perfect / Heel / Toe / Thin).

## Related

Firmware + web lab live in the separate `golf_mat` repo. This app is the iPhone client.
