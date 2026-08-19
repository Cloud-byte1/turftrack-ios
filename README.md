# TurfTrack (iOS)

Native iPhone app for the FairLie / GolfMat pressure-mat system.

Connects over Bluetooth Low Energy to the ESP32 mat (`GolfMat`, service `0xAB12`, notify `0xAB13`), arms a zeroed strike map, then shows hit strength as white intensity plus letter grades **A–F**.

## Requirements

- Mac with **Xcode 15+**
- iPhone on **iOS 16+**
- Apple ID (free signing works for your own device)
- GolfMat firmware advertising as `GolfMat`

## Open & run

1. Clone this repo on a Mac
2. Open `TurfTrack.xcodeproj` in Xcode
3. Select your Team under **Signing & Capabilities**
4. Plug in an iPhone, pick it as the run destination
5. Build & run

On first launch, allow Bluetooth when prompted.

## App flow

1. **Connect** — scans for `GolfMat` / service `0xAB12`
2. **Calibrate / Zero** — zeros the on-screen pads and arms tracking (UI arm; hardware tare still requires USB `CAL` on the ESP until a BLE write char is added)
3. Pads stay at **0** until a real strike (`impact_quality ≥ 35`)
4. Strike paints pads white by strength and shows grade **A–F**

## Packet format

Matches `ble_swing_packet_t` in the golf_mat firmware (`components/comms/ble.h`) — little-endian, 52+ bytes notify payload.

## Related repo

Firmware + web lab: keep your existing `golf_mat` repository separate. This app is the iPhone client only.
