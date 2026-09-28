# TurfTrack Swing Visualizer — Test Environment

A standalone React and Three.js prototype for validating TurfTrack swing paths,
strike pressure, grading, and coaching feedback before integrating the same logic
into FairLie.

## Setup

```bash
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).

## Usage

1. Select a club: 7 Iron, Driver, or Wedge.
2. Click one of the four swing presets or generate a random swing.
3. Drag the 3D view to rotate it and scroll to zoom.
4. Inspect the club-face heatmap and pressure distribution.
5. Review metric grades, corrections, and the last five swings.

## Live hardware (two ESP32s)

Radar and mat are separate boards. Connect both in the lab — each uses its own
COM port (or mat BLE + radar USB).

## Backend (sessions, profile, clubhouse)

```bash
cd ../backend
npm install
npm run dev
```

API on [http://127.0.0.1:8787](http://127.0.0.1:8787). Vite proxies `/api`.

App tabs:
- **Lab** — live mat + radar + simulator
- **Sessions** — saved practice history
- **Clubhouse** — leaderboard, challenges, feed, bulletin
- **Profile** — golfer card, goals, stats

If the backend is down, the UI still works with local fallback data.

### Mat ESP (FSR / swing) — USB or BLE

Mat firmware prints:

`GMSWING <hex-packet>`

1. Flash the mat ESP-IDF firmware.
2. Quit any serial monitor on that COM port.
3. Click **Mat USB** or **Mat BLE**.
4. Zero sensors, initialize swing, then strike.

### Radar ESP (XM125) — USB

Flash [`radar_esp/radar_stream.ino`](../radar_esp/radar_stream.ino) to the second
ESP32 (XM125 on I2C). It streams:

`GMRADAR,<ms>,<mph>,<dist_mm>,<intra>,<inter>,<valid>`

1. Quit Serial Monitor on the radar COM port.
2. Click **Connect Radar USB** and pick the **other** COM port (not the mat).
3. Ball-speed samples merge into mat swings within ~500 ms.

See [`radar_esp/README.md`](../radar_esp/README.md).

### Seeed XIAO Sense (optional IMU) — USB

Flash [`xiao/swing_imu_stream.ino`](../xiao/swing_imu_stream.ino), then **XIAO**.
See [`xiao/README.md`](../xiao/README.md).

## Production build

```bash
npm run build
npm run preview
```

## Moving to FairLie

The framework-neutral files in `src/engine/` and `src/data/` can be copied to
`my-app/src/engine/` with no browser dependencies. The components need only the
usual React Native substitutions (`View`/`Text`, `Pressable`, and `StyleSheet`).
The 3D view can be adapted to an Expo-compatible Three.js renderer while keeping
the same reconstructed path-point and grading data.
