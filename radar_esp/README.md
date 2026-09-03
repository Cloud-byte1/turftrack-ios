# Radar ESP bridge (second board)

Flash `radar_stream.ino` to a **separate** ESP32 that has the XM125 on I2C.

Default pins: **SDA=GPIO8**, **SCL=GPIO9** (ESP32-S3). Override with build flags if needed.

## Stream format

```
GMRADAR,<timestamp_ms>,<speed_mph>,<dist_mm>,<intra>,<inter>,<valid>
```

## Strike Lab

1. Flash mat firmware to the FSR ESP → **Connect Mat BLE** or **Mat USB**
2. Flash this sketch to the radar ESP → **Connect Radar USB** (pick the other COM port)
3. Both stay connected; swings from the mat merge with the latest radar sample
