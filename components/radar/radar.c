#include "radar.h"
#include "imu.h"
#include "driver/i2c_master.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <math.h>
#include <string.h>

static const char *TAG = "radar";

#define XM125_ADDR                 0x52
#define XM125_I2C_HZ               400000
#define XM125_XFER_TIMEOUT_MS      100
#define XM125_BUSY_TIMEOUT_MS      5000

#define XM125_REG_VERSION          0x0000
#define XM125_REG_PROTOCOL_STATUS  0x0001
#define XM125_REG_DETECTOR_STATUS  0x0003
#define XM125_REG_PRESENCE_RESULT  0x0010
#define XM125_REG_PRESENCE_DIST    0x0011
#define XM125_REG_INTRA_SCORE      0x0012
#define XM125_REG_INTER_SCORE      0x0013
#define XM125_REG_START            0x0052
#define XM125_REG_END              0x0053
#define XM125_REG_COMMAND          0x0100

#define XM125_CMD_APPLY_CONFIG     1u
#define XM125_CMD_START_DETECTOR   2u
#define XM125_CMD_STOP_DETECTOR    3u
#define XM125_CMD_RESET_MODULE     1381192737u

#define XM125_BUSY                 0x80000000u
#define XM125_DETECTOR_ERROR       0x10000000u
#define XM125_CONFIG_APPLY_OK      0x00000080u

#define XM125_PRESENCE_DETECTED        0x00000001u
#define XM125_PRESENCE_DETECTED_STICKY 0x00000002u

#define XM125_START_MM             300u
#define XM125_END_MM               2500u
#define XM125_SPEED_MAX_MPS        80.0f
/* Quiet baseline averages ~1220 in this setup; only report speed above that. */
#define XM125_INTRA_MOTION_MIN     1220u

static i2c_master_dev_handle_t s_dev;
static bool s_ready;
static int64_t s_last_presence_us;

static void clear_reading(radar_reading_t *out)
{
    out->presence_distance_mm = 0;
    out->intra_score = 0;
    out->inter_score = 0;
    out->speed_mps = 0.0f;
    out->speed_mph = 0.0f;
    out->speed_kmh = 0.0f;
    out->object_detected = false;
    out->valid = false;
}

static void estimate_speed_from_intra(uint32_t intra_score, radar_reading_t *out)
{
    /* No MPH unless intra score shows real motion. */
    if (intra_score < XM125_INTRA_MOTION_MIN) {
        out->speed_mps = 0.0f;
        out->speed_mph = 0.0f;
        out->speed_kmh = 0.0f;
        return;
    }

    float speed_mps = ((float)intra_score / 5000.0f) * 50.0f;
    if (speed_mps > XM125_SPEED_MAX_MPS) {
        speed_mps = XM125_SPEED_MAX_MPS;
    }
    out->speed_mps = speed_mps;
    out->speed_mph = speed_mps * 2.23694f;
    out->speed_kmh = speed_mps * 3.6f;
}

/* I2C write: 2-byte BE address + 4-byte BE data. */
static esp_err_t xm125_write_reg(uint16_t reg_addr, uint32_t reg_data)
{
    const uint8_t frame[6] = {
        (uint8_t)((reg_addr >> 8) & 0xFF),
        (uint8_t)(reg_addr & 0xFF),
        (uint8_t)((reg_data >> 24) & 0xFF),
        (uint8_t)((reg_data >> 16) & 0xFF),
        (uint8_t)((reg_data >> 8) & 0xFF),
        (uint8_t)(reg_data & 0xFF),
    };
    return i2c_master_transmit(s_dev, frame, sizeof(frame), XM125_XFER_TIMEOUT_MS);
}

/* I2C read: write 2-byte BE address, then read 4-byte BE data. */
static esp_err_t xm125_read_reg(uint16_t reg_addr, uint32_t *reg_data)
{
    if (reg_data == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    const uint8_t addr[2] = {
        (uint8_t)((reg_addr >> 8) & 0xFF),
        (uint8_t)(reg_addr & 0xFF),
    };
    esp_err_t err = i2c_master_transmit(s_dev, addr, sizeof(addr), XM125_XFER_TIMEOUT_MS);
    if (err != ESP_OK) {
        return err;
    }

    uint8_t data[4] = {0};
    err = i2c_master_receive(s_dev, data, sizeof(data), XM125_XFER_TIMEOUT_MS);
    if (err != ESP_OK) {
        return err;
    }

    *reg_data = ((uint32_t)data[0] << 24) |
                ((uint32_t)data[1] << 16) |
                ((uint32_t)data[2] << 8) |
                (uint32_t)data[3];
    return ESP_OK;
}

static esp_err_t wait_not_busy(uint32_t timeout_ms)
{
    const int64_t deadline_us =
        esp_timer_get_time() + ((int64_t)timeout_ms * 1000LL);

    while (true) {
        uint32_t status = 0;
        esp_err_t err = xm125_read_reg(XM125_REG_DETECTOR_STATUS, &status);
        if (err != ESP_OK) {
            return err;
        }
        if ((status & XM125_BUSY) == 0u) {
            return ESP_OK;
        }
        if (esp_timer_get_time() >= deadline_us) {
            ESP_LOGE(TAG, "BUSY timeout (status=0x%08lX)", (unsigned long)status);
            return ESP_ERR_TIMEOUT;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

bool radar_presence_within_us(int64_t around_us, int64_t window_us)
{
    if (s_last_presence_us <= 0 || window_us < 0) {
        return false;
    }
    int64_t dt = s_last_presence_us - around_us;
    if (dt < 0) {
        dt = -dt;
    }
    return dt <= window_us;
}

esp_err_t radar_init(void)
{
    s_ready = false;
    s_dev = NULL;
    s_last_presence_us = 0;

    if (g_i2c_bus == NULL) {
        ESP_LOGE(TAG, "Shared I2C bus unavailable");
        return ESP_ERR_INVALID_STATE;
    }

    esp_err_t err = i2c_master_probe(g_i2c_bus, XM125_ADDR, XM125_XFER_TIMEOUT_MS);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "XM125 not found at 0x%02X: %s",
                 XM125_ADDR, esp_err_to_name(err));
        return ESP_ERR_NOT_FOUND;
    }

    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = XM125_ADDR,
        .scl_speed_hz = XM125_I2C_HZ,
    };
    err = i2c_master_bus_add_device(g_i2c_bus, &dev_cfg, &s_dev);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Could not add XM125 device: %s", esp_err_to_name(err));
        return err;
    }

    /* 1. Read DETECTOR_STATUS and log. */
    uint32_t status = 0;
    err = xm125_read_reg(XM125_REG_DETECTOR_STATUS, &status);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "DETECTOR_STATUS read failed: %s", esp_err_to_name(err));
        return err;
    }
    ESP_LOGI(TAG, "DETECTOR_STATUS=0x%08lX", (unsigned long)status);

    /* 2-3. Configure measurement range. */
    err = xm125_write_reg(XM125_REG_START, XM125_START_MM);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "START write failed: %s", esp_err_to_name(err));
        return err;
    }
    err = xm125_write_reg(XM125_REG_END, XM125_END_MM);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "END write failed: %s", esp_err_to_name(err));
        return err;
    }

    /* 4. APPLY_CONFIGURATION */
    err = xm125_write_reg(XM125_REG_COMMAND, XM125_CMD_APPLY_CONFIG);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "APPLY_CONFIGURATION failed: %s", esp_err_to_name(err));
        return err;
    }

    /* 5. Wait until BUSY clears. */
    err = wait_not_busy(XM125_BUSY_TIMEOUT_MS);
    if (err != ESP_OK) {
        return err;
    }

    /* 6. Confirm CONFIG_APPLY_OK. */
    err = xm125_read_reg(XM125_REG_DETECTOR_STATUS, &status);
    if (err != ESP_OK) {
        return err;
    }
    ESP_LOGI(TAG, "DETECTOR_STATUS after apply=0x%08lX", (unsigned long)status);
    if ((status & XM125_CONFIG_APPLY_OK) == 0u) {
        ESP_LOGE(TAG, "CONFIG_APPLY_OK not set (status=0x%08lX)",
                 (unsigned long)status);
        return ESP_ERR_INVALID_RESPONSE;
    }
    if ((status & XM125_DETECTOR_ERROR) != 0u) {
        ESP_LOGE(TAG, "DETECTOR_ERROR set (status=0x%08lX)",
                 (unsigned long)status);
        return ESP_ERR_INVALID_RESPONSE;
    }

    /* 7. START_DETECTOR */
    err = xm125_write_reg(XM125_REG_COMMAND, XM125_CMD_START_DETECTOR);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "START_DETECTOR failed: %s", esp_err_to_name(err));
        return err;
    }

    /* 8. Wait until BUSY clears. */
    err = wait_not_busy(XM125_BUSY_TIMEOUT_MS);
    if (err != ESP_OK) {
        return err;
    }

    s_ready = true;
    /* 9. Log started. */
    ESP_LOGI(TAG, "XM125 presence detector started");
    return ESP_OK;
}

esp_err_t radar_read(radar_reading_t *out)
{
    if (out == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    clear_reading(out);

    if (!s_ready || s_dev == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    /* 1. Read PRESENCE_RESULT. */
    uint32_t presence_result = 0;
    esp_err_t err = xm125_read_reg(XM125_REG_PRESENCE_RESULT, &presence_result);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "PRESENCE_RESULT read failed: %s", esp_err_to_name(err));
        return err;
    }

    /* 2. Check PRESENCE_DETECTED. */
    if ((presence_result & XM125_PRESENCE_DETECTED) != 0u) {
        uint32_t distance_mm = 0;
        uint32_t intra_score = 0;
        uint32_t inter_score = 0;

        err = xm125_read_reg(XM125_REG_PRESENCE_DIST, &distance_mm);
        if (err != ESP_OK) {
            return err;
        }
        err = xm125_read_reg(XM125_REG_INTRA_SCORE, &intra_score);
        if (err != ESP_OK) {
            return err;
        }
        err = xm125_read_reg(XM125_REG_INTER_SCORE, &inter_score);
        if (err != ESP_OK) {
            return err;
        }

        out->object_detected = true;
        out->presence_distance_mm = distance_mm;
        out->intra_score = intra_score;
        out->inter_score = inter_score;
        estimate_speed_from_intra(intra_score, out);
        out->valid = true;
        s_last_presence_us = esp_timer_get_time();

        /* Only print speed when there is significant movement. */
        if (out->speed_mph > 0.0f) {
            ESP_LOGI(TAG,
                     "Dist:%lumm Intra:%lu Speed:%.1fmph (%.1fm/s)",
                     (unsigned long)out->presence_distance_mm,
                     (unsigned long)out->intra_score,
                     out->speed_mph,
                     out->speed_mps);
        }
    }

    return ESP_OK;
}
