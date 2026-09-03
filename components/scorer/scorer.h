#pragma once

#include <stdint.h>
#include "event_detector.h"

typedef struct {
    uint8_t impact_quality;
    uint8_t contact_zone_label;
    uint16_t estimated_distance_m;
    uint8_t consistency_hint;
    uint8_t direction_penalty;
    char direction_label[16];
} swing_score_t;

swing_score_t scorer_compute(swing_event_t *event);
