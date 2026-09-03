# Seeed XIAO nRF52840 Sense → Swing Visualizer

Your XIAO talks to the PC over **USB only** (not through the ESP).

```text
XIAO Sense IMU  --USB-->  PC browser (Connect XIAO)
ESP mat FSRs    --USB/BLE-->  PC browser (optional, separate)
```

## Requirements

- **XIAO nRF52840 Sense** (the one with the onboard IMU). Plain XIAO nRF52840 has no IMU.
- Arduino IDE with:
  - Board package: **Seeed nRF52 mbed-enabled Boards**
  - Library: **Seeed Arduino LSM6DS3**

## Flash the streamer sketch

1. Open `xiao/swing_imu_stream.ino` in Arduino IDE.
2. Select board **XIAO nRF52840 Sense**.
3. Upload.
4. Open Serial Monitor at **115200** once to confirm you see:
   - `GMREADY,xiao_sense`
   - repeating `GMIMU,...` lines
   - `GMIMPACT,...` when you shake/swing the board
5. **Close Serial Monitor** (required — the browser needs the COM port).

## Connect in the visualizer

1. `npm run dev` → http://localhost:5173 in Chrome/Edge
2. Plug XIAO into the PC by USB-C
3. Click **Connect XIAO** → pick the XIAO COM port
4. Swing / shake the board — UI should show **Live XIAO Swing**

## Notes

- ESP and XIAO are separate USB devices. Use **Connect XIAO** for motion path; **Connect ESP USB** for mat pressure packets.
- If Connect fails with “port busy”, close Arduino Serial Monitor and `idf.py monitor`.
