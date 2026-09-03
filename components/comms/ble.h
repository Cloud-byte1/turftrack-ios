#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "event_detector.h"
#include "scorer.h"

typedef struct __attribute__((packed)) {
    uint32_t timestamp_ms;
    uint16_t fsr_peak[6];
    uint16_t impact_duration_us;
    uint8_t impact_zone;
    uint8_t impact_quality;
    uint8_t contact_zone_label;
    uint16_t estimated_distance_m;
    uint8_t consistency_hint;
    uint8_t flags;
    int16_t accel_x_mg;
    int16_t accel_y_mg;
    int16_t accel_z_mg;
    int16_t gyro_x_mdps;
    int16_t gyro_y_mdps;
    int16_t gyro_z_mdps;
    int16_t yaw_deg10;
    uint8_t strike_zone;
    uint8_t strike_direction;
    uint8_t heel_pressure_pct;
    uint8_t center_pressure_pct;
    uint8_t toe_pressure_pct;
    uint8_t direction_penalty;
    int16_t radar_speed_mph10;    // mph * 10
    int16_t radar_distance_mm;    // distance in mm
    uint16_t radar_intra_score;   // raw intra score
    uint8_t  radar_valid;         // 1 if valid
} ble_swing_packet_t;

_Static_assert(sizeof(ble_swing_packet_t) <= 64,
               "BLE swing packet must fit in 64 bytes");

void ble_init(void);
void ble_send_swing_result(swing_event_t *event, swing_score_t *score);
/** Always emit the packed swing on USB/UART as: GMSWING <hex>\n */
void serial_send_swing_result(swing_event_t *event, swing_score_t *score);

extern bool g_ble_connected;
