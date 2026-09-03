#include "sensor.h"
#include "imu.h"
#include "driver/i2c_master.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include <math.h>
#include <string.h>

static const char *TAG = "sensor";

#define SENSOR_I2C_PORT          I2C_NUM_0
#define XM125_ADDR               0x52
#define ADS1115_I2C_HZ           400000
#define ADS1115_XFER_TIMEOUT_MS  50
#define ADS1115_PROBE_TIMEOUT_MS 100
/* 128 SPS ≈ 7.8 ms/conversion; allow a little margin. */
#define ADS1115_CONVERSION_MS    10
#define ADS1115_REG_CONVERSION   0x00
#define ADS1115_REG_CONFIG       0x01
/* LSB for PGA ±2.048 V. */
#define ADS1115_LSB_MV           0.0625f

#define BASELINE_WINDOW_US       2000000LL
#define BASELINE_NOISE_FLOOR_MV  3U

static const uint8_t ADS1115_ADDRS[] = {
    0x48, 0x49, 0x4A, 0x4B
};

static i2c_master_bus_handle_t s_i2c_bus = NULL;
static i2c_master_dev_handle_t s_ads1 = NULL;
static i2c_master_dev_handle_t s_ads2 = NULL;
static volatile bool s_running;

TaskHandle_t  g_sensor_task_handle = NULL;
QueueHandle_t g_sensor_queue       = NULL;

static uint16_t s_baseline_mv[SENSOR_COUNT];
static uint32_t s_baseline_sum[SENSOR_COUNT];
static uint32_t s_baseline_count;
static int64_t  s_baseline_deadline_us;
static bool     s_baseline_ready;
static volatile bool s_recalibrate_request;

/*
 * Single-ended AIN0..AIN3:
 * OS=1, PGA=±2.048V (2x), mode=single-shot, DR=128 SPS, comparator disabled.
 */
static const uint16_t s_channel_configs[4] = {
    0xC583,
    0xD583,
    0xE583,
    0xF583,
};

static esp_err_t ads1115_read_channel(i2c_master_dev_handle_t dev,
                                      uint8_t mux_bits,
                                      uint16_t *voltage_mv)
{
    if (dev == NULL || voltage_mv == NULL || mux_bits < 0x4 || mux_bits > 0x7) {
        return ESP_ERR_INVALID_ARG;
    }

    const uint16_t config = s_channel_configs[mux_bits - 0x4];
    const uint8_t config_write[3] = {
        ADS1115_REG_CONFIG,
        (uint8_t)(config >> 8),
        (uint8_t)(config & 0xFF),
    };

    esp_err_t err = i2c_master_transmit(
        dev, config_write, sizeof(config_write), ADS1115_XFER_TIMEOUT_MS
    );
    if (err != ESP_OK) {
        return err;
    }

    vTaskDelay(pdMS_TO_TICKS(ADS1115_CONVERSION_MS));

    const uint8_t conversion_reg = ADS1115_REG_CONVERSION;
    uint8_t raw_bytes[2] = {0};
    err = i2c_master_transmit_receive(
        dev,
        &conversion_reg,
        sizeof(conversion_reg),
        raw_bytes,
        sizeof(raw_bytes),
        ADS1115_XFER_TIMEOUT_MS
    );
    if (err != ESP_OK) {
        return err;
    }

    const int16_t raw = (int16_t)(((uint16_t)raw_bytes[0] << 8) | raw_bytes[1]);
    const float mv = (float)raw * ADS1115_LSB_MV;
    *voltage_mv = mv <= 0.0f ? 0U : (uint16_t)lroundf(mv);
    return ESP_OK;
}

static esp_err_t add_ads1115_device(uint8_t address,
                                    i2c_master_dev_handle_t *device)
{
    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = address,
        .scl_speed_hz = ADS1115_I2C_HZ,
    };
    return i2c_master_bus_add_device(s_i2c_bus, &dev_cfg, device);
}

/* Confirm an ACK'ing address behaves like an ADS1115 (not BNO085 at 0x4A/0x4B). */
static bool ads1115_verify_device(uint8_t address)
{
    i2c_master_dev_handle_t tmp = NULL;
    if (add_ads1115_device(address, &tmp) != ESP_OK) {
        return false;
    }

    const uint8_t config_write[3] = {
        ADS1115_REG_CONFIG,
        (uint8_t)(s_channel_configs[0] >> 8),
        (uint8_t)(s_channel_configs[0] & 0xFF),
    };
    esp_err_t err = i2c_master_transmit(
        tmp, config_write, sizeof(config_write), ADS1115_XFER_TIMEOUT_MS
    );
    if (err != ESP_OK) {
        (void)i2c_master_bus_rm_device(tmp);
        return false;
    }

    const uint8_t config_reg = ADS1115_REG_CONFIG;
    uint8_t raw[2] = {0};
    err = i2c_master_transmit_receive(
        tmp, &config_reg, 1, raw, sizeof(raw), ADS1115_XFER_TIMEOUT_MS
    );
    (void)i2c_master_bus_rm_device(tmp);
    if (err != ESP_OK) {
        return false;
    }

    const uint16_t cfg = ((uint16_t)raw[0] << 8) | raw[1];
    /* PGA[11:9] == 010 (±2.048V), DR[7:5] == 100 (128 SPS). */
    return ((cfg & 0x0E00u) == 0x0400u) && ((cfg & 0x00E0u) == 0x0080u);
}

static esp_err_t ads1115_configure_device(i2c_master_dev_handle_t dev, uint8_t address)
{
    /* Prime PGA ±2.048V / 128 SPS via AIN0 single-shot config. */
    const uint8_t config_write[3] = {
        ADS1115_REG_CONFIG,
        (uint8_t)(s_channel_configs[0] >> 8),
        (uint8_t)(s_channel_configs[0] & 0xFF),
    };
    esp_err_t err = i2c_master_transmit(
        dev, config_write, sizeof(config_write), ADS1115_XFER_TIMEOUT_MS
    );
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "ADS1115 at 0x%02X config failed: %s",
                 address, esp_err_to_name(err));
        return err;
    }
    ESP_LOGI(TAG, "ADS1115 at 0x%02X initialized", address);
    return ESP_OK;
}

static uint8_t ads1115_scan_addresses(uint8_t found_addrs[4])
{
    uint8_t found_count = 0;
    for (int i = 0; i < 4; i++) {
        const uint8_t addr = ADS1115_ADDRS[i];
        esp_err_t ret = i2c_master_probe(
            s_i2c_bus, addr, ADS1115_PROBE_TIMEOUT_MS
        );
        if (ret != ESP_OK) {
            continue;
        }
        if (!ads1115_verify_device(addr)) {
            ESP_LOGW(TAG, "I2C device at 0x%02X is not an ADS1115 — skipping",
                     addr);
            continue;
        }
        found_addrs[found_count++] = addr;
        ESP_LOGI(TAG, "ADS1115 found at 0x%02X", addr);
    }
    return found_count;
}

static esp_err_t ads1115_init_devices(void)
{
    s_ads1 = NULL;
    s_ads2 = NULL;

    if (g_i2c_bus != NULL) {
        s_i2c_bus = g_i2c_bus;
    } else {
        esp_err_t err = i2c_master_get_bus_handle(SENSOR_I2C_PORT, &s_i2c_bus);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "Existing I2C bus unavailable: %s", esp_err_to_name(err));
            return err;
        }
    }

    /* Give ADS1115 boards time to power up before first scan. */
    vTaskDelay(pdMS_TO_TICKS(100));

    esp_err_t err = i2c_master_probe(s_i2c_bus, XM125_ADDR, ADS1115_PROBE_TIMEOUT_MS);
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "XM125 found at 0x%02X", XM125_ADDR);
    } else {
        ESP_LOGW(TAG, "XM125 not found at 0x%02X", XM125_ADDR);
    }

    uint8_t found_addrs[4] = {0};
    uint8_t found_count = 0;

    for (int retry = 0; retry < 3; retry++) {
        memset(found_addrs, 0, sizeof(found_addrs));
        found_count = ads1115_scan_addresses(found_addrs);
        if (found_count >= 2) {
            break;
        }
        if (retry < 2) {
            ESP_LOGI(TAG, "Retry %d finding ADS1115...", retry + 1);
            vTaskDelay(pdMS_TO_TICKS(500));
        }
    }

    ESP_LOGI(TAG, "ADS1115 scan complete: found %u board(s)",
             (unsigned)found_count);

    if (found_count == 0) {
        ESP_LOGE(TAG, "No ADS1115 found at any address — FSR readings will be 0");
        return ESP_OK;
    }

    /* Board 1 = first address → FSR 0-3 */
    err = add_ads1115_device(found_addrs[0], &s_ads1);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Could not add ADS1115 at 0x%02X: %s",
                 found_addrs[0], esp_err_to_name(err));
        s_ads1 = NULL;
        return ESP_OK;
    }
    if (ads1115_configure_device(s_ads1, found_addrs[0]) != ESP_OK) {
        (void)i2c_master_bus_rm_device(s_ads1);
        s_ads1 = NULL;
        return ESP_OK;
    }

    if (found_count >= 2) {
        /* Board 2 = second address → FSR 4-5 */
        err = add_ads1115_device(found_addrs[1], &s_ads2);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "Could not add ADS1115 at 0x%02X: %s",
                     found_addrs[1], esp_err_to_name(err));
            s_ads2 = NULL;
            ESP_LOGW(TAG, "Continuing with Board1=0x%02X only (FSR 0-3)",
                     found_addrs[0]);
            return ESP_OK;
        }
        if (ads1115_configure_device(s_ads2, found_addrs[1]) != ESP_OK) {
            (void)i2c_master_bus_rm_device(s_ads2);
            s_ads2 = NULL;
            ESP_LOGW(TAG, "Continuing with Board1=0x%02X only (FSR 0-3)",
                     found_addrs[0]);
            return ESP_OK;
        }
        ESP_LOGI(TAG, "Using Board1=0x%02X Board2=0x%02X",
                 found_addrs[0], found_addrs[1]);
    } else {
        ESP_LOGW(TAG, "Only one ADS1115 at 0x%02X — using FSR 0-3 only; FSR 4-5 = 0",
                 found_addrs[0]);
    }

    return ESP_OK;
}

static esp_err_t sensor_read_fsr(uint16_t raw_mv[SENSOR_COUNT])
{
    memset(raw_mv, 0, sizeof(uint16_t) * SENSOR_COUNT);

    /* No boards: keep zeros and continue. */
    if (s_ads1 == NULL) {
        return ESP_OK;
    }

    for (uint8_t channel = 0; channel < 4; ++channel) {
        esp_err_t err = ads1115_read_channel(
            s_ads1, (uint8_t)(0x4 + channel), &raw_mv[channel]
        );
        if (err != ESP_OK) {
            return err;
        }
    }

    if (s_ads2 != NULL) {
        for (uint8_t channel = 0; channel < 2; ++channel) {
            esp_err_t err = ads1115_read_channel(
                s_ads2, (uint8_t)(0x4 + channel), &raw_mv[4 + channel]
            );
            if (err != ESP_OK) {
                return err;
            }
        }
    }

    return ESP_OK;
}

static void baseline_begin(int64_t now_us)
{
    memset(s_baseline_sum, 0, sizeof(s_baseline_sum));
    s_baseline_count = 0;
    s_baseline_ready = false;
    s_baseline_deadline_us = now_us + BASELINE_WINDOW_US;
    ESP_LOGI(TAG, "Grass baseline: keep mat at rest for 2s...");
}

static void baseline_accumulate(const uint16_t raw_mv[SENSOR_COUNT])
{
    for (int i = 0; i < SENSOR_COUNT; ++i) {
        s_baseline_sum[i] += raw_mv[i];
    }
    s_baseline_count += 1;
}

static void baseline_finish(void)
{
    if (s_baseline_count == 0) {
        memset(s_baseline_mv, 0, sizeof(s_baseline_mv));
    } else {
        for (int i = 0; i < SENSOR_COUNT; ++i) {
            s_baseline_mv[i] = (uint16_t)(s_baseline_sum[i] / s_baseline_count);
        }
    }
    s_baseline_ready = true;
    ESP_LOGI(TAG,
             "Grass baseline ready (n=%u): %u %u %u %u %u %u mV -> delta 0 at rest",
             (unsigned)s_baseline_count,
             s_baseline_mv[0], s_baseline_mv[1], s_baseline_mv[2],
             s_baseline_mv[3], s_baseline_mv[4], s_baseline_mv[5]);
}

static void apply_tare(const uint16_t raw_mv[SENSOR_COUNT],
                       uint16_t delta_mv[SENSOR_COUNT])
{
    for (int i = 0; i < SENSOR_COUNT; ++i) {
        if (!s_baseline_ready || raw_mv[i] <= s_baseline_mv[i]) {
            delta_mv[i] = 0;
        } else {
            uint16_t delta = (uint16_t)(raw_mv[i] - s_baseline_mv[i]);
            delta_mv[i] = (delta < BASELINE_NOISE_FLOOR_MV) ? 0 : delta;
        }
    }
}

void sensor_request_recalibrate(void)
{
    s_recalibrate_request = true;
}

bool sensor_baseline_ready(void)
{
    return s_baseline_ready;
}

void sensor_get_baseline_mv(uint16_t out[SENSOR_COUNT])
{
    if (out != NULL) {
        memcpy(out, s_baseline_mv, sizeof(s_baseline_mv));
    }
}

esp_err_t sensor_init(void)
{
    ESP_LOGI(TAG, "Initializing ADS1115 sensor queue...");
    g_sensor_queue = xQueueCreate(32, sizeof(sensor_sample_t));
    if (g_sensor_queue == NULL) {
        return ESP_ERR_NO_MEM;
    }

    memset(s_baseline_mv, 0, sizeof(s_baseline_mv));
    s_baseline_ready = false;
    s_recalibrate_request = false;
    s_running = false;
    return ESP_OK;
}

esp_err_t sensor_start(void)
{
    esp_err_t err = ads1115_init_devices();
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "ADS1115 init issue (%s) — continuing with available boards",
                 esp_err_to_name(err));
    }
    baseline_begin(esp_timer_get_time());
    s_running = true;
    return ESP_OK;
}

esp_err_t sensor_stop(void)
{
    s_running = false;
    return ESP_OK;
}

void sensor_task(void *arg)
{
    (void)arg;
    ESP_LOGI(TAG, "ADS1115 sensor task running on Core %d", xPortGetCoreID());
    sensor_sample_t sample = {0};
    static uint32_t last_print = 0;

    while (1) {
        if (!s_running) {
            vTaskDelay(pdMS_TO_TICKS(20));
            continue;
        }

        if (s_recalibrate_request) {
            s_recalibrate_request = false;
            baseline_begin(esp_timer_get_time());
        }

        uint16_t raw_mv[SENSOR_COUNT] = {0};
        esp_err_t err = sensor_read_fsr(raw_mv);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "ADS1115 read failed: %s", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(20));
            continue;
        }

        sample.timestamp_us = (uint32_t)esp_timer_get_time();
        memcpy(sample.fsr_raw_mv, raw_mv, sizeof(raw_mv));

        if (!s_baseline_ready) {
            baseline_accumulate(raw_mv);
            if ((int64_t)esp_timer_get_time() >= s_baseline_deadline_us) {
                baseline_finish();
            }
            memset(sample.fsr_mv, 0, sizeof(sample.fsr_mv));
        } else {
            apply_tare(raw_mv, sample.fsr_mv);
        }

        uint32_t now = xTaskGetTickCount();
        if (now - last_print > pdMS_TO_TICKS(500)) {
            last_print = now;
            const int boards = (s_ads1 != NULL ? 1 : 0) + (s_ads2 != NULL ? 1 : 0);
            ESP_LOGI("fsr",
                     "boards=%d raw:%d %d %d %d %d %d | delta:%d %d %d %d %d %d mV",
                     boards,
                     (int)sample.fsr_raw_mv[0], (int)sample.fsr_raw_mv[1],
                     (int)sample.fsr_raw_mv[2], (int)sample.fsr_raw_mv[3],
                     (int)sample.fsr_raw_mv[4], (int)sample.fsr_raw_mv[5],
                     (int)sample.fsr_mv[0], (int)sample.fsr_mv[1],
                     (int)sample.fsr_mv[2], (int)sample.fsr_mv[3],
                     (int)sample.fsr_mv[4], (int)sample.fsr_mv[5]);
        }

        xQueueSend(g_sensor_queue, &sample, 0);
    }
}
