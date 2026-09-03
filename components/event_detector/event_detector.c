#include <string.h>
#include "event_detector.h"
#include "esp_log.h"
#include "freertos/task.h"

/* Thresholds are on grass-tared delta mV (rest = 0). */
#define IMPACT_THRESHOLD_MV       40U   /* more sensitive — start on lighter press */
#define IMPACT_CONFIRM_PEAK_MV    80U   /* confirm softer strikes / hand presses */
#define IMPACT_MIN_DURATION_US   500U
#define IMPACT_MAX_DURATION_US  8000U   /* real strike is short; reject slow lean */
#define IMPACT_COOLDOWN_US    900000U   /* ~0.9s between swings */
#define STRIKE_ZONE_CLAIM_PCT     40U
#define STRIKE_DIR_BIAS_PCT       18U

static const char *TAG = "event_detector";
static swing_state_t s_state = STATE_IDLE;
static uint32_t s_impact_start_us;
static uint16_t s_peaks[6];
static uint32_t s_cooldown_end_us = 0;

QueueHandle_t g_event_queue;

static uint16_t max_channel(const uint16_t values[6])
{
    uint16_t peak = 0;
    for (size_t i = 0; i < 6; ++i) {
        if (values[i] > peak) {
            peak = values[i];
        }
    }
    return peak;
}

static bool any_above_threshold(const sensor_sample_t *sample)
{
    return max_channel(sample->fsr_mv) > IMPACT_THRESHOLD_MV;
}

static void update_peaks(const sensor_sample_t *sample)
{
    for (size_t i = 0; i < 6; ++i) {
        if (sample->fsr_mv[i] > s_peaks[i]) {
            s_peaks[i] = sample->fsr_mv[i];
        }
    }
}

static strike_zone_t zone_from_peak_index(uint8_t idx)
{
    switch (idx) {
    case 0:
    case 4:
        return STRIKE_ZONE_HEEL;
    case 2:
        return STRIKE_ZONE_HEEL_CENTER;
    case 1:
    case 5:
        return STRIKE_ZONE_TOE;
    case 3:
        return STRIKE_ZONE_TOE_CENTER;
    default:
        return STRIKE_ZONE_CENTER;
    }
}

static void compute_strike_analysis(swing_event_t *event)
{
    const uint32_t heel_sum =
        (uint32_t)event->fsr_peak[0] + (uint32_t)event->fsr_peak[2] +
        (uint32_t)event->fsr_peak[4];
    const uint32_t toe_sum =
        (uint32_t)event->fsr_peak[1] + (uint32_t)event->fsr_peak[3] +
        (uint32_t)event->fsr_peak[5];
    const uint32_t center_sum =
        (uint32_t)event->fsr_peak[2] + (uint32_t)event->fsr_peak[3];
    const uint32_t front_sum =
        (uint32_t)event->fsr_peak[0] + (uint32_t)event->fsr_peak[1];
    const uint32_t rear_sum =
        (uint32_t)event->fsr_peak[4] + (uint32_t)event->fsr_peak[5];
    const uint32_t total = heel_sum + toe_sum;

    if (total == 0) {
        event->strike_zone = STRIKE_ZONE_CENTER;
        event->strike_direction = STRIKE_DIR_STRAIGHT;
        event->heel_pressure_pct = 0;
        event->center_pressure_pct = 0;
        event->toe_pressure_pct = 0;
        return;
    }

    event->heel_pressure_pct = (uint8_t)((heel_sum * 100U) / total);
    event->toe_pressure_pct = (uint8_t)((toe_sum * 100U) / total);
    event->center_pressure_pct = (uint8_t)((center_sum * 100U) / total);

    const uint8_t heel_pct = event->heel_pressure_pct;
    const uint8_t center_pct = event->center_pressure_pct;
    const uint8_t toe_pct = event->toe_pressure_pct;

    uint8_t peak_idx = 0;
    uint16_t peak_val = 0;
    for (uint8_t i = 0; i < 6; ++i) {
        if (event->fsr_peak[i] > peak_val) {
            peak_val = event->fsr_peak[i];
            peak_idx = i;
        }
    }

    if (center_pct >= STRIKE_ZONE_CLAIM_PCT &&
        center_sum >= heel_sum / 2U && center_sum >= toe_sum / 2U &&
        (peak_idx == 2 || peak_idx == 3)) {
        event->strike_zone = STRIKE_ZONE_CENTER;
    } else if (heel_pct >= STRIKE_ZONE_CLAIM_PCT && heel_pct >= toe_pct) {
        if (event->fsr_peak[2] >= event->fsr_peak[0] &&
            event->fsr_peak[2] >= event->fsr_peak[4]) {
            event->strike_zone = STRIKE_ZONE_HEEL_CENTER;
        } else {
            event->strike_zone = STRIKE_ZONE_HEEL;
        }
    } else if (toe_pct >= STRIKE_ZONE_CLAIM_PCT && toe_pct >= heel_pct) {
        if (event->fsr_peak[3] >= event->fsr_peak[1] &&
            event->fsr_peak[3] >= event->fsr_peak[5]) {
            event->strike_zone = STRIKE_ZONE_TOE_CENTER;
        } else {
            event->strike_zone = STRIKE_ZONE_TOE;
        }
    } else {
        event->strike_zone = zone_from_peak_index(peak_idx);
    }

    if (heel_pct > (uint8_t)(toe_pct + STRIKE_DIR_BIAS_PCT)) {
        event->strike_direction = STRIKE_DIR_LEFT;
    } else if (toe_pct > (uint8_t)(heel_pct + STRIKE_DIR_BIAS_PCT)) {
        event->strike_direction = STRIKE_DIR_RIGHT;
    } else {
        const uint32_t fr_total = front_sum + rear_sum + center_sum;
        if (fr_total == 0) {
            event->strike_direction = STRIKE_DIR_STRAIGHT;
        } else {
            const uint8_t front_pct = (uint8_t)((front_sum * 100U) / fr_total);
            const uint8_t rear_pct = (uint8_t)((rear_sum * 100U) / fr_total);
            if (front_pct > (uint8_t)(rear_pct + STRIKE_DIR_BIAS_PCT)) {
                event->strike_direction = STRIKE_DIR_PUSH;
            } else if (rear_pct > (uint8_t)(front_pct + STRIKE_DIR_BIAS_PCT)) {
                event->strike_direction = STRIKE_DIR_PULL;
            } else {
                event->strike_direction = STRIKE_DIR_STRAIGHT;
            }
        }
    }
}

bool event_detector_update(sensor_sample_t *sample, swing_event_t *out_event)
{
    if (sample == NULL || out_event == NULL) {
        return false;
    }

    const bool active = any_above_threshold(sample);

    switch (s_state) {
    case STATE_IDLE:
        if (active && (int32_t)(sample->timestamp_us - s_cooldown_end_us) >= 0) {
            memset(s_peaks, 0, sizeof(s_peaks));
            s_impact_start_us = sample->timestamp_us;
            update_peaks(sample);
            s_state = STATE_IMPACT;
        }
        break;

    case STATE_IMPACT:
        if (active) {
            update_peaks(sample);
            /* Abort if this looks like leaning on the mat, not a strike. */
            if ((sample->timestamp_us - s_impact_start_us) > IMPACT_MAX_DURATION_US) {
                memset(s_peaks, 0, sizeof(s_peaks));
                s_state = STATE_POST_IMPACT;
            }
        } else {
            const uint32_t duration = sample->timestamp_us - s_impact_start_us;
            s_state = STATE_POST_IMPACT;
            const uint16_t peak = max_channel(s_peaks);
            if (duration >= IMPACT_MIN_DURATION_US &&
                duration <= IMPACT_MAX_DURATION_US &&
                peak >= IMPACT_CONFIRM_PEAK_MV) {
                uint32_t weighted_sum = 0;
                uint32_t total = 0;
                memset(out_event, 0, sizeof(*out_event));
                out_event->timestamp_us = s_impact_start_us;
                memcpy(out_event->fsr_peak, s_peaks, sizeof(s_peaks));
                out_event->impact_duration_us =
                    duration > UINT16_MAX ? UINT16_MAX : (uint16_t)duration;
                for (uint8_t i = 0; i < 6; ++i) {
                    weighted_sum += (uint32_t)s_peaks[i] * i;
                    total += s_peaks[i];
                }
                out_event->impact_zone = total == 0
                    ? 0 : (uint8_t)((weighted_sum + total / 2) / total);
                if (out_event->impact_zone > 5) {
                    out_event->impact_zone = 5;
                }
                out_event->flags = SWING_FLAG_IMPACT;
                compute_strike_analysis(out_event);
                imu_read(&out_event->imu);
                memset(s_peaks, 0, sizeof(s_peaks));
                s_cooldown_end_us = sample->timestamp_us + IMPACT_COOLDOWN_US;
                return true;
            }
            memset(s_peaks, 0, sizeof(s_peaks));
        }
        break;

    case STATE_POST_IMPACT:
        if (!active) {
            s_state = STATE_IDLE;
        }
        break;
    }

    return false;
}

static void event_detector_task(void *arg)
{
    (void)arg;
    sensor_sample_t sample;
    swing_event_t event;

    while (true) {
        if (xQueueReceive(g_sensor_queue, &sample, pdMS_TO_TICKS(100)) == pdTRUE &&
            event_detector_update(&sample, &event)) {
            xQueueSend(g_event_queue, &event, 0);
        }
    }
}

void event_detector_init(void)
{
    g_event_queue = xQueueCreate(8, sizeof(swing_event_t));
    if (g_event_queue == NULL) {
        ESP_LOGE(TAG, "Event queue creation failed");
        abort();
    }
    BaseType_t created = xTaskCreate(event_detector_task, "event_detector", 3072,
                                     NULL, 5, NULL);
    if (created != pdPASS) {
        ESP_LOGE(TAG, "Detector task creation failed");
        abort();
    }
    ESP_LOGI(TAG,
             "Event detector ready (delta thr=%umV confirm=%umV cooldown=%uus)",
             (unsigned)IMPACT_THRESHOLD_MV,
             (unsigned)IMPACT_CONFIRM_PEAK_MV,
             (unsigned)IMPACT_COOLDOWN_US);
}
