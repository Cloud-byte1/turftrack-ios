#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "esp_log.h"
#include "esp_err.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "sensor.h"
#include "event_detector.h"
#include "imu.h"
#include "radar.h"
#include "scorer.h"
#include "ble.h"
#include "driver/i2c_master.h"
#include <stdio.h>
#include <string.h>

static const char *TAG = "main";
static TaskHandle_t s_comms_task_handle;

static const char *zone_label(strike_zone_t zone)
{
    switch (zone) {
    case STRIKE_ZONE_HEEL:        return "Heel";
    case STRIKE_ZONE_HEEL_CENTER: return "Heel-Ctr";
    case STRIKE_ZONE_CENTER:      return "Center";
    case STRIKE_ZONE_TOE_CENTER:  return "Toe-Ctr";
    case STRIKE_ZONE_TOE:         return "Toe";
    default:                      return "Unknown";
    }
}

static void comms_task(void *arg)
{
    (void)arg;
    swing_event_t event;
    while (true) {
        if (xQueueReceive(g_event_queue, &event, pdMS_TO_TICKS(100)) == pdTRUE) {
            swing_score_t score = scorer_compute(&event);
            /* Skip near-zero quality noise that slipped past the detector. */
            if (score.impact_quality < 20) {
                continue;
            }

            radar_reading_t radar = {0};
            (void)radar_read(&radar);
            const bool presence_near =
                radar.object_detected ||
                radar_presence_within_us(esp_timer_get_time(), 500000LL);
            if ((event.flags & SWING_FLAG_IMPACT) != 0 && presence_near) {
                event.flags |= SWING_FLAG_BALL_STRIKE;
                if (radar.speed_mph > 0.0f) {
                    ESP_LOGI("radar", "STRIKE: speed=%.1fmph dist=%lumm",
                             radar.speed_mph,
                             (unsigned long)radar.presence_distance_mm);
                } else {
                    ESP_LOGI("radar", "STRIKE: dist=%lumm (no significant motion)",
                             (unsigned long)radar.presence_distance_mm);
                }
            }

            serial_send_swing_result(&event, &score);
            ble_send_swing_result(&event, &score);
            ESP_LOGI(TAG,
                     "Swing: quality=%u zone=%s zone_id=%u dir=%s dir_id=%u "
                     "heel=%u%% center=%u%% toe=%u%% estimated_distance=%um penalty=%u "
                     "peaks=%u,%u,%u,%u,%u,%u flags=0x%02X",
                     score.impact_quality,
                     zone_label(event.strike_zone),
                     (unsigned)event.strike_zone,
                     score.direction_label,
                     (unsigned)event.strike_direction,
                     event.heel_pressure_pct,
                     event.center_pressure_pct,
                     event.toe_pressure_pct,
                     score.estimated_distance_m,
                     score.direction_penalty,
                     event.fsr_peak[0], event.fsr_peak[1], event.fsr_peak[2],
                     event.fsr_peak[3], event.fsr_peak[4], event.fsr_peak[5],
                     event.flags);
        }
    }
}

/* Type CAL + Enter in the serial monitor to re-tare grass load. */
static void calib_cmd_task(void *arg)
{
    (void)arg;
    char line[32];
    ESP_LOGI(TAG, "Send 'CAL' over serial to re-zero grass baseline");
    while (true) {
        if (fgets(line, sizeof(line), stdin) == NULL) {
            vTaskDelay(pdMS_TO_TICKS(200));
            continue;
        }
        if (strncmp(line, "CAL", 3) == 0 || strncmp(line, "cal", 3) == 0) {
            sensor_request_recalibrate();
            ESP_LOGI(TAG, "Recalibrate requested — keep mat at rest for 2s");
        }
    }
}

void app_main(void)
{
    ESP_LOGI(TAG, "Golf Mat starting...");

    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
        ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    ESP_ERROR_CHECK(sensor_init());

    esp_err_t imu_ret = imu_init();
    if (imu_ret == ESP_ERR_NOT_FOUND) {
        ESP_LOGW(TAG, "IMU not found — continuing without BNO085 (%s)",
                 esp_err_to_name(imu_ret));
    } else if (imu_ret != ESP_OK) {
        ESP_LOGW(TAG, "IMU init failed — continuing without BNO085 (%s)",
                 esp_err_to_name(imu_ret));
    }

    /* Temporary one-shot scan. imu_init() creates the shared bus after
       sensor_init(), so scanning any earlier would use a null handle. */
    ESP_LOGI("i2c_scan", "Scanning I2C bus...");
    ESP_LOGI("i2c_scan", "Looking for XM125 at 0x52");
    if (g_i2c_bus == NULL) {
        ESP_LOGW("i2c_scan", "I2C bus is unavailable; skipping scan");
    } else {
        for (uint8_t addr = 1; addr < 127; ++addr) {
            esp_err_t scan_ret = i2c_master_probe(g_i2c_bus, addr, 100);
            if (scan_ret == ESP_OK) {
                ESP_LOGI("i2c_scan", "Found device at 0x%02X", addr);
            }
        }
    }
    ESP_LOGI("i2c_scan", "Scan complete");

    esp_err_t radar_ret = radar_init();
    if (radar_ret == ESP_ERR_NOT_FOUND) {
        ESP_LOGW(TAG, "Radar not found — continuing without XM125 (%s)",
                 esp_err_to_name(radar_ret));
    } else if (radar_ret != ESP_OK) {
        ESP_LOGW(TAG, "Radar init failed — continuing without XM125 (%s)",
                 esp_err_to_name(radar_ret));
    }

    event_detector_init();
    ble_init();

    BaseType_t created = xTaskCreatePinnedToCore(
        sensor_task,
        "sensor",
        4096,
        NULL,
        5,
        &g_sensor_task_handle,
        1
    );
    ESP_ERROR_CHECK(created == pdPASS ? ESP_OK : ESP_ERR_NO_MEM);

    created = xTaskCreatePinnedToCore(
        comms_task,
        "comms",
        4096,
        NULL,
        4,
        &s_comms_task_handle,
        0
    );
    ESP_ERROR_CHECK(created == pdPASS ? ESP_OK : ESP_ERR_NO_MEM);

    created = xTaskCreatePinnedToCore(
        calib_cmd_task,
        "calib_cmd",
        3072,
        NULL,
        2,
        NULL,
        0
    );
    ESP_ERROR_CHECK(created == pdPASS ? ESP_OK : ESP_ERR_NO_MEM);

    esp_err_t sensor_ret = sensor_start();
    if (sensor_ret != ESP_OK) {
        ESP_LOGW(TAG, "Sensor start failed: %d — continuing", sensor_ret);
    }
    ESP_LOGI(TAG, "System running — leave turf at rest while baseline learns (2s)");

    unsigned loop_count = 0;
    while (true) {
        /* Poll radar often so presence stays fresh for the 500ms strike window. */
        vTaskDelay(pdMS_TO_TICKS(100));
        radar_reading_t radar = {0};
        (void)radar_read(&radar);

        if ((++loop_count % 50u) == 0u) {
            ESP_LOGI(TAG, "Stack HWM: sensor=%u comms=%u; BLE=%s; baseline=%s",
                     (unsigned)uxTaskGetStackHighWaterMark(g_sensor_task_handle),
                     (unsigned)uxTaskGetStackHighWaterMark(s_comms_task_handle),
                     g_ble_connected ? "connected" : "disconnected",
                     sensor_baseline_ready() ? "ready" : "learning");
        }
    }
}
