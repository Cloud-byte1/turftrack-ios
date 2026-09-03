/*
 * TurfTrack — Seeed XIAO nRF52840 Sense IMU streamer
 *
 * Board: Seeed nRF52 mbed-enabled Boards → XIAO nRF52840 Sense
 * Library: Seeed Arduino LSM6DS3 (Library Manager)
 *
 * USB serial @ 115200:
 *   GMIMU,<ms>,<ax_g>,<ay_g>,<az_g>,<gx_dps>,<gy_dps>,<gz_dps>
 *   GMIMPACT,<ms>     // when swing/impact spike detected
 *   GMREADY           // once at boot
 *
 * Close Arduino Serial Monitor before Connect XIAO in the visualizer
 * (only one app can open the COM port).
 */

#include "LSM6DS3.h"
#include "Wire.h"

LSM6DS3 imu(I2C_MODE, 0x6A);

static const uint32_t SAMPLE_HZ = 100;
static const uint32_t SAMPLE_PERIOD_MS = 1000 / SAMPLE_HZ;
static const float IMPACT_THRESHOLD_G = 2.8f;   // deliberate impact, not normal motion
static const uint32_t IMPACT_COOLDOWN_MS = 900;

uint32_t lastSampleMs = 0;
uint32_t lastImpactMs = 0;
float baselineMag = 1.0f;

void setup() {
  Serial.begin(115200);
  // Don't block forever if host isn't listening yet.
  uint32_t start = millis();
  while (!Serial && (millis() - start) < 2000) {
    delay(10);
  }

  if (imu.begin() != 0) {
    Serial.println("GMERR,imu_init_failed");
    while (true) {
      delay(1000);
    }
  }

  Serial.println("GMREADY,xiao_sense");
  lastSampleMs = millis();
}

void loop() {
  const uint32_t now = millis();
  if (now - lastSampleMs < SAMPLE_PERIOD_MS) {
    return;
  }
  lastSampleMs = now;

  const float ax = imu.readFloatAccelX();
  const float ay = imu.readFloatAccelY();
  const float az = imu.readFloatAccelZ();
  const float gx = imu.readFloatGyroX();
  const float gy = imu.readFloatGyroY();
  const float gz = imu.readFloatGyroZ();

  const float mag = sqrtf(ax * ax + ay * ay + az * az);

  // Slow baseline track while quiet.
  if (mag < 1.6f) {
    baselineMag = baselineMag * 0.98f + mag * 0.02f;
  }

  Serial.print("GMIMU,");
  Serial.print(now);
  Serial.print(',');
  Serial.print(ax, 4);
  Serial.print(',');
  Serial.print(ay, 4);
  Serial.print(',');
  Serial.print(az, 4);
  Serial.print(',');
  Serial.print(gx, 3);
  Serial.print(',');
  Serial.print(gy, 3);
  Serial.print(',');
  Serial.println(gz, 3);

  if (mag > baselineMag + IMPACT_THRESHOLD_G &&
      (now - lastImpactMs) > IMPACT_COOLDOWN_MS) {
    lastImpactMs = now;
    Serial.print("GMIMPACT,");
    Serial.println(now);
  }
}
