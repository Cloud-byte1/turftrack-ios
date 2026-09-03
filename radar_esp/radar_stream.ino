/*
 * Dedicated XM125 radar bridge for a second ESP32.
 * Streams: GMRADAR,<ms>,<mph>,<dist_mm>,<intra>,<inter>,<valid>
 *
 * Board: ESP32 / ESP32-S3
 * I2C: SDA=8 SCL=9 (change below if needed)
 * Flash with Arduino IDE, then Connect Radar USB in Strike Lab
 * (pick this board's COM port — not the mat ESP).
 */

#include <Wire.h>

static const uint8_t XM125_ADDR = 0x52;
static const uint16_t REG_DETECTOR_STATUS = 0x0003;
static const uint16_t REG_PRESENCE_RESULT = 0x0010;
static const uint16_t REG_PRESENCE_DIST = 0x0011;
static const uint16_t REG_INTRA = 0x0012;
static const uint16_t REG_INTER = 0x0013;
static const uint16_t REG_START = 0x0052;
static const uint16_t REG_END = 0x0053;
static const uint16_t REG_COMMAND = 0x0100;

static const uint32_t CMD_APPLY = 1;
static const uint32_t CMD_START = 2;
static const uint32_t BUSY_BIT = 0x80000000UL;
static const uint32_t CONFIG_OK = 0x00000080UL;
static const uint32_t PRESENCE_BIT = 0x00000001UL;
static const uint32_t INTRA_MOTION_MIN = 1220;

#ifndef RADAR_SDA
#define RADAR_SDA 8
#endif
#ifndef RADAR_SCL
#define RADAR_SCL 9
#endif

static bool g_ready = false;

static bool writeReg(uint16_t reg, uint32_t value) {
  Wire.beginTransmission(XM125_ADDR);
  Wire.write((uint8_t)(reg >> 8));
  Wire.write((uint8_t)(reg & 0xFF));
  Wire.write((uint8_t)(value >> 24));
  Wire.write((uint8_t)(value >> 16));
  Wire.write((uint8_t)(value >> 8));
  Wire.write((uint8_t)(value & 0xFF));
  return Wire.endTransmission() == 0;
}

static bool readReg(uint16_t reg, uint32_t *value) {
  Wire.beginTransmission(XM125_ADDR);
  Wire.write((uint8_t)(reg >> 8));
  Wire.write((uint8_t)(reg & 0xFF));
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((int)XM125_ADDR, 4) != 4) return false;
  uint32_t v = 0;
  v |= ((uint32_t)Wire.read()) << 24;
  v |= ((uint32_t)Wire.read()) << 16;
  v |= ((uint32_t)Wire.read()) << 8;
  v |= (uint32_t)Wire.read();
  *value = v;
  return true;
}

static bool waitNotBusy(uint32_t timeoutMs) {
  const uint32_t start = millis();
  while (millis() - start < timeoutMs) {
    uint32_t status = 0;
    if (!readReg(REG_DETECTOR_STATUS, &status)) return false;
    if ((status & BUSY_BIT) == 0) return true;
    delay(10);
  }
  return false;
}

static bool initXm125() {
  uint32_t status = 0;
  if (!readReg(REG_DETECTOR_STATUS, &status)) return false;
  if (!writeReg(REG_START, 300)) return false;
  if (!writeReg(REG_END, 2500)) return false;
  if (!writeReg(REG_COMMAND, CMD_APPLY)) return false;
  if (!waitNotBusy(5000)) return false;
  if (!readReg(REG_DETECTOR_STATUS, &status)) return false;
  if ((status & CONFIG_OK) == 0) return false;
  if (!writeReg(REG_COMMAND, CMD_START)) return false;
  if (!waitNotBusy(5000)) return false;
  return true;
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Wire.begin(RADAR_SDA, RADAR_SCL);
  Wire.setClock(400000);
  delay(100);

  Serial.println("radar_bridge boot");
  g_ready = initXm125();
  Serial.println(g_ready ? "XM125 ready" : "XM125 init failed");
}

void loop() {
  if (!g_ready) {
    delay(500);
    g_ready = initXm125();
    return;
  }

  uint32_t presence = 0;
  uint32_t dist = 0;
  uint32_t intra = 0;
  uint32_t inter = 0;
  float speedMph = 0.0f;
  int valid = 0;

  if (readReg(REG_PRESENCE_RESULT, &presence) && (presence & PRESENCE_BIT)) {
    readReg(REG_PRESENCE_DIST, &dist);
    readReg(REG_INTRA, &intra);
    readReg(REG_INTER, &inter);
    if (intra >= INTRA_MOTION_MIN) {
      float speedMps = ((float)intra / 5000.0f) * 50.0f;
      if (speedMps > 80.0f) speedMps = 80.0f;
      speedMph = speedMps * 2.23694f;
      valid = 1;
    }
  }

  Serial.print("GMRADAR,");
  Serial.print(millis());
  Serial.print(',');
  Serial.print(speedMph, 2);
  Serial.print(',');
  Serial.print(dist);
  Serial.print(',');
  Serial.print(intra);
  Serial.print(',');
  Serial.print(inter);
  Serial.print(',');
  Serial.println(valid);

  delay(100);
}
