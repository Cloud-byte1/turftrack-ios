#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

typedef struct {
    uint32_t presence_distance_mm;  // distance in mm
    uint32_t intra_score;           // raw intra score
    uint32_t inter_score;           // raw inter score
    float    speed_mps;             // estimated speed m/s
    float    speed_mph;             // estimated speed mph
    float    speed_kmh;             // estimated speed km/h
    bool     object_detected;       // presence detected
    bool     valid;                 // reading is valid
} radar_reading_t;

esp_err_t radar_init(void);
esp_err_t radar_read(radar_reading_t *out);

/** True if presence was seen within window_us of around_us (esp_timer). */
bool radar_presence_within_us(int64_t around_us, int64_t window_us);
