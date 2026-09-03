#include <math.h>
#include <string.h>
#include "scorer.h"

static uint16_t maximum_peak(const swing_event_t *event)
{
    uint16_t peak = 0;
    for (size_t i = 0; i < 6; ++i) {
        if (event->fsr_peak[i] > peak) {
            peak = event->fsr_peak[i];
        }
    }
    return peak;
}

static uint8_t scale_quality(uint16_t peak, uint16_t low_mv,
                             uint16_t high_mv, uint8_t low_score,
                             uint8_t high_score)
{
    if (peak <= low_mv) {
        return low_score;
    }
    if (peak >= high_mv) {
        return high_score;
    }
    return (uint8_t)(low_score +
        ((uint32_t)(peak - low_mv) * (high_score - low_score)) /
        (high_mv - low_mv));
}

static uint16_t scale_distance(uint16_t peak, uint16_t low_mv,
                               uint16_t high_mv, uint16_t low_m,
                               uint16_t high_m)
{
    if (peak <= low_mv) {
        return low_m;
    }
    if (peak >= high_mv) {
        return high_m;
    }
    return (uint16_t)(low_m +
        ((uint32_t)(peak - low_mv) * (high_m - low_m)) / (high_mv - low_m));
}

static float accel_magnitude(const imu_reading_t *imu)
{
    return sqrtf(imu->accel_x * imu->accel_x +
                 imu->accel_y * imu->accel_y +
                 imu->accel_z * imu->accel_z);
}

static float gyro_magnitude(const imu_reading_t *imu)
{
    return sqrtf(imu->gyro_x * imu->gyro_x +
                 imu->gyro_y * imu->gyro_y +
                 imu->gyro_z * imu->gyro_z);
}

static void set_direction_fields(swing_score_t *score, const swing_event_t *event)
{
    if (event->strike_direction == STRIKE_DIR_PUSH) {
        score->direction_penalty = 25;
        strncpy(score->direction_label, "Push", sizeof(score->direction_label));
    } else if (event->strike_direction == STRIKE_DIR_PULL) {
        score->direction_penalty = 25;
        strncpy(score->direction_label, "Pull", sizeof(score->direction_label));
    } else {
        switch (event->strike_zone) {
        case STRIKE_ZONE_HEEL:
            score->direction_penalty = 35;
            strncpy(score->direction_label, "Left", sizeof(score->direction_label));
            break;
        case STRIKE_ZONE_TOE:
            score->direction_penalty = 35;
            strncpy(score->direction_label, "Right", sizeof(score->direction_label));
            break;
        case STRIKE_ZONE_HEEL_CENTER:
            score->direction_penalty = 15;
            strncpy(score->direction_label, "Slight Left",
                    sizeof(score->direction_label));
            break;
        case STRIKE_ZONE_TOE_CENTER:
            score->direction_penalty = 15;
            strncpy(score->direction_label, "Slight Right",
                    sizeof(score->direction_label));
            break;
        case STRIKE_ZONE_CENTER:
        default:
            if (event->strike_direction == STRIKE_DIR_LEFT) {
                score->direction_penalty = 30;
                strncpy(score->direction_label, "Left",
                        sizeof(score->direction_label));
            } else if (event->strike_direction == STRIKE_DIR_RIGHT) {
                score->direction_penalty = 30;
                strncpy(score->direction_label, "Right",
                        sizeof(score->direction_label));
            } else {
                score->direction_penalty = 0;
                strncpy(score->direction_label, "Straight",
                        sizeof(score->direction_label));
            }
            break;
        }
    }
    score->direction_label[sizeof(score->direction_label) - 1] = '\0';
}

/* Reward centered contact like a real strike; punish thin/edge spray. */
static uint8_t contact_variation_adjust(const swing_event_t *event, uint8_t quality)
{
    int q = (int)quality;
    switch (event->strike_zone) {
    case STRIKE_ZONE_CENTER:
        q += 8;
        break;
    case STRIKE_ZONE_HEEL_CENTER:
    case STRIKE_ZONE_TOE_CENTER:
        q += 2;
        break;
    case STRIKE_ZONE_HEEL:
    case STRIKE_ZONE_TOE:
        q -= 10;
        break;
    default:
        break;
    }

    /* Sweet-spot share of force. */
    if (event->center_pressure_pct >= 40) {
        q += 5;
    } else if (event->center_pressure_pct < 20) {
        q -= 8;
    }

    /* Very short pulse ≈ thin; longer solid contact ≈ flush. */
    if (event->impact_duration_us < 400U) {
        q -= 12;
    } else if (event->impact_duration_us > 700U && event->impact_duration_us < 2500U) {
        q += 4;
    }

    if (q < 0) {
        q = 0;
    }
    if (q > 100) {
        q = 100;
    }
    return (uint8_t)q;
}

swing_score_t scorer_compute(swing_event_t *event)
{
    swing_score_t score = {0};
    if (event == NULL) {
        return score;
    }

    strncpy(score.direction_label, "Straight", sizeof(score.direction_label));
    score.direction_label[sizeof(score.direction_label) - 1] = '\0';

    /* Peaks are grass-tared deltas. */
    const uint16_t peak = maximum_peak(event);

    if (peak < 140U) {
        score.contact_zone_label = (uint8_t)event->strike_zone;
        score.consistency_hint = event->center_pressure_pct;
        set_direction_fields(&score, event);
        return score;
    }

    if (peak >= 280U && event->impact_duration_us > 450U) {
        score.impact_quality = scale_quality(peak, 280, 420, 88, 100);
        score.estimated_distance_m = scale_distance(peak, 280, 420, 160, 250);
    } else if (peak >= 200U && event->impact_duration_us > 350U) {
        score.impact_quality = scale_quality(peak, 200, 280, 68, 87);
        score.estimated_distance_m = scale_distance(peak, 200, 280, 110, 159);
    } else if (peak >= 140U) {
        score.impact_quality = scale_quality(peak, 140, 200, 40, 67);
        score.estimated_distance_m = scale_distance(peak, 140, 200, 55, 109);
    } else {
        score.impact_quality = 0;
        score.estimated_distance_m = 0;
    }

    score.impact_quality = contact_variation_adjust(event, score.impact_quality);
    score.contact_zone_label = (uint8_t)event->strike_zone;
    score.consistency_hint = event->center_pressure_pct;
    set_direction_fields(&score, event);

    score.estimated_distance_m = (uint16_t)(
        ((uint32_t)score.estimated_distance_m *
         (100U - score.direction_penalty)) / 100U);

    if (event->imu.valid) {
        const float accel_mag = accel_magnitude(&event->imu);
        const float gyro_mag = gyro_magnitude(&event->imu);

        if (accel_mag < 1.5f && peak < 180U) {
            if (score.impact_quality > 15) {
                score.impact_quality = (uint8_t)(score.impact_quality - 15);
            } else {
                score.impact_quality = 0;
            }
        } else if (accel_mag > 8.0f && score.impact_quality < 95) {
            score.impact_quality = (uint8_t)(score.impact_quality + 5);
        }

        if (gyro_mag > 0.5f) {
            float speed_scale = 1.0f + (gyro_mag / 20.0f);
            if (speed_scale > 1.4f) {
                speed_scale = 1.4f;
            }
            uint32_t scaled =
                (uint32_t)((float)score.estimated_distance_m * speed_scale);
            if (scaled > 300U) {
                scaled = 300U;
            }
            score.estimated_distance_m = (uint16_t)scaled;
        }
    }

    return score;
}
