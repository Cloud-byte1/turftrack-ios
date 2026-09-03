#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "imu.h"
#include "sensor.h"

/* Strike location on club face (2x3 pad grid: heel col | toe col). */
typedef enum {
    STRIKE_ZONE_HEEL        = 0,
    STRIKE_ZONE_HEEL_CENTER = 1,
    STRIKE_ZONE_CENTER      = 2,
    STRIKE_ZONE_TOE_CENTER  = 3,
    STRIKE_ZONE_TOE         = 4,
} strike_zone_t;

/* Strike direction — where the ball would go. */
typedef enum {
    STRIKE_DIR_STRAIGHT = 0,
    STRIKE_DIR_LEFT     = 1,
    STRIKE_DIR_RIGHT    = 2,
    STRIKE_DIR_PUSH     = 3,
    STRIKE_DIR_PULL     = 4,
} strike_direction_t;

#define SWING_FLAG_IMPACT      0x01u
#define SWING_FLAG_BALL_STRIKE 0x02u

typedef struct {
    uint32_t timestamp_us;
    uint16_t fsr_peak[6];
    uint16_t impact_duration_us;
    uint8_t impact_zone;
    uint8_t flags;
    imu_reading_t imu;
    strike_zone_t strike_zone;
    strike_direction_t strike_direction;
    uint8_t heel_pressure_pct;
    uint8_t toe_pressure_pct;
    uint8_t center_pressure_pct;
} swing_event_t;

typedef enum {
    STATE_IDLE,
    STATE_IMPACT,
    STATE_POST_IMPACT,
} swing_state_t;

void event_detector_init(void);
bool event_detector_update(sensor_sample_t *sample, swing_event_t *out_event);

extern QueueHandle_t g_event_queue;
