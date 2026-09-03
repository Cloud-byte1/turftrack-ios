#include <math.h>
#include <string.h>
#include "imu.h"
#include "driver/i2c_master.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"

#define IMU_I2C_PORT           I2C_NUM_0
#define IMU_SDA_GPIO           8
#define IMU_SCL_GPIO           9
#define IMU_I2C_HZ             400000
#define IMU_ADDR_PRIMARY       0x4A
#define IMU_ADDR_SECONDARY     0x4B
#define IMU_XFER_TIMEOUT_MS    50
#define IMU_POLL_PERIOD_MS     20
#define IMU_HEADER_LEN         4
#define IMU_MAX_PACKET         128

#define SHTP_CH_COMMAND        0
#define SHTP_CH_EXECUTABLE     1
#define SHTP_CH_CONTROL        2
#define SHTP_CH_REPORTS        3

#define SH2_SET_FEATURE_CMD    0xFD
#define SH2_PRODUCT_ID_REQ     0xF9
#define SH2_PRODUCT_ID_RESP    0xF8
#define SH2_BASE_TIMESTAMP     0xFB

#define SENSOR_GYRO_CALIBRATED 0x02
#define SENSOR_LINEAR_ACCEL    0x04
#define SENSOR_ROTATION_VECTOR 0x05

#define Q_TO_FLOAT(q, n)       ((float)(q) * (1.0f / (float)(1 << (n))))

static const char *TAG = "imu";

i2c_master_bus_handle_t g_i2c_bus;
static i2c_master_dev_handle_t s_dev;
static uint8_t s_addr;
static uint8_t s_seq[6];
static bool s_ready;
static imu_reading_t s_latest;
static SemaphoreHandle_t s_lock;
static int64_t s_last_ok_us;

static float q_to_float(int16_t q, int n)
{
    return Q_TO_FLOAT(q, n);
}

static void quat_to_euler(float qi, float qj, float qk, float qr,
                          float *roll, float *pitch, float *yaw)
{
    *roll = atan2f(2.0f * (qr * qi + qj * qk),
                   1.0f - 2.0f * (qi * qi + qj * qj)) * (180.0f / (float)M_PI);
    float sinp = 2.0f * (qr * qj - qk * qi);
    if (sinp > 1.0f) {
        sinp = 1.0f;
    } else if (sinp < -1.0f) {
        sinp = -1.0f;
    }
    *pitch = asinf(sinp) * (180.0f / (float)M_PI);
    *yaw = atan2f(2.0f * (qr * qk + qi * qj),
                  1.0f - 2.0f * (qj * qj + qk * qk)) * (180.0f / (float)M_PI);
}

static esp_err_t shtp_write(uint8_t channel, const uint8_t *cargo, uint16_t cargo_len)
{
    uint8_t packet[IMU_MAX_PACKET];
    const uint16_t total = (uint16_t)(IMU_HEADER_LEN + cargo_len);
    if (total > sizeof(packet) || channel >= sizeof(s_seq)) {
        return ESP_ERR_INVALID_SIZE;
    }

    packet[0] = (uint8_t)(total & 0xFF);
    packet[1] = (uint8_t)((total >> 8) & 0x7F);
    packet[2] = channel;
    packet[3] = s_seq[channel]++;
    if (cargo_len > 0) {
        memcpy(&packet[IMU_HEADER_LEN], cargo, cargo_len);
    }

    esp_err_t err = i2c_master_transmit(s_dev, packet, total, IMU_XFER_TIMEOUT_MS);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "SHTP write ch=%u failed: %s", channel, esp_err_to_name(err));
    }
    return err;
}

static esp_err_t shtp_read(uint8_t *channel, uint8_t *cargo, uint16_t *cargo_len,
                           uint16_t cargo_cap)
{
    uint8_t header[IMU_HEADER_LEN];
    esp_err_t err = i2c_master_receive(s_dev, header, sizeof(header), IMU_XFER_TIMEOUT_MS);
    if (err != ESP_OK) {
        return err;
    }

    uint16_t packet_len = (uint16_t)header[0] | ((uint16_t)(header[1] & 0x7F) << 8);
    if (packet_len == 0 || packet_len == 0x7FFF) {
        *cargo_len = 0;
        return ESP_ERR_NOT_FOUND;
    }
    if (packet_len < IMU_HEADER_LEN || packet_len > IMU_MAX_PACKET) {
        ESP_LOGW(TAG, "Invalid SHTP length %u", packet_len);
        return ESP_ERR_INVALID_SIZE;
    }

    *channel = header[2];
    const uint16_t remaining = (uint16_t)(packet_len - IMU_HEADER_LEN);
    if (remaining == 0) {
        *cargo_len = 0;
        return ESP_OK;
    }

    uint8_t body[IMU_MAX_PACKET];
    err = i2c_master_receive(s_dev, body, remaining, IMU_XFER_TIMEOUT_MS);
    if (err != ESP_OK) {
        return err;
    }

    const uint16_t copy_len = remaining < cargo_cap ? remaining : cargo_cap;
    memcpy(cargo, body, copy_len);
    *cargo_len = copy_len;
    return ESP_OK;
}

static void parse_sensor_reports(const uint8_t *cargo, uint16_t cargo_len)
{
    uint16_t idx = 0;
    imu_reading_t update = s_latest;
    bool changed = false;

    while (idx < cargo_len) {
        const uint8_t report_id = cargo[idx];
        if (report_id == SH2_BASE_TIMESTAMP) {
            idx = (uint16_t)(idx + 5);
            continue;
        }

        uint16_t report_len = 0;
        switch (report_id) {
        case SENSOR_GYRO_CALIBRATED:
            report_len = 10;
            break;
        case SENSOR_LINEAR_ACCEL:
            report_len = 10;
            break;
        case SENSOR_ROTATION_VECTOR:
            report_len = 14;
            break;
        default:
            /* Unknown/short report — stop parsing this packet. */
            return;
        }

        if ((uint16_t)(idx + report_len) > cargo_len) {
            return;
        }

        const uint8_t *payload = &cargo[idx];
        if (report_id == SENSOR_GYRO_CALIBRATED) {
            int16_t gx = (int16_t)((uint16_t)payload[4] | ((uint16_t)payload[5] << 8));
            int16_t gy = (int16_t)((uint16_t)payload[6] | ((uint16_t)payload[7] << 8));
            int16_t gz = (int16_t)((uint16_t)payload[8] | ((uint16_t)payload[9] << 8));
            update.gyro_x = q_to_float(gx, 9);
            update.gyro_y = q_to_float(gy, 9);
            update.gyro_z = q_to_float(gz, 9);
            changed = true;
        } else if (report_id == SENSOR_LINEAR_ACCEL) {
            int16_t ax = (int16_t)((uint16_t)payload[4] | ((uint16_t)payload[5] << 8));
            int16_t ay = (int16_t)((uint16_t)payload[6] | ((uint16_t)payload[7] << 8));
            int16_t az = (int16_t)((uint16_t)payload[8] | ((uint16_t)payload[9] << 8));
            update.accel_x = q_to_float(ax, 8);
            update.accel_y = q_to_float(ay, 8);
            update.accel_z = q_to_float(az, 8);
            changed = true;
        } else if (report_id == SENSOR_ROTATION_VECTOR) {
            int16_t qi = (int16_t)((uint16_t)payload[4] | ((uint16_t)payload[5] << 8));
            int16_t qj = (int16_t)((uint16_t)payload[6] | ((uint16_t)payload[7] << 8));
            int16_t qk = (int16_t)((uint16_t)payload[8] | ((uint16_t)payload[9] << 8));
            int16_t qr = (int16_t)((uint16_t)payload[10] | ((uint16_t)payload[11] << 8));
            quat_to_euler(q_to_float(qi, 14), q_to_float(qj, 14),
                          q_to_float(qk, 14), q_to_float(qr, 14),
                          &update.roll, &update.pitch, &update.yaw);
            changed = true;
        }

        idx = (uint16_t)(idx + report_len);
    }

    if (changed) {
        update.valid = true;
        if (xSemaphoreTake(s_lock, pdMS_TO_TICKS(5)) == pdTRUE) {
            s_latest = update;
            s_last_ok_us = esp_timer_get_time();
            xSemaphoreGive(s_lock);
        }
    }
}

static esp_err_t enable_sensor(uint8_t report_id, uint32_t interval_us)
{
    uint8_t cmd[17] = {0};
    cmd[0] = SH2_SET_FEATURE_CMD;
    cmd[1] = report_id;
    cmd[2] = 0; /* flags */
    cmd[3] = 0; /* change sensitivity LSB */
    cmd[4] = 0; /* change sensitivity MSB */
    cmd[5] = (uint8_t)(interval_us & 0xFF);
    cmd[6] = (uint8_t)((interval_us >> 8) & 0xFF);
    cmd[7] = (uint8_t)((interval_us >> 16) & 0xFF);
    cmd[8] = (uint8_t)((interval_us >> 24) & 0xFF);
    /* batch interval and sensor-specific remain zero */
    return shtp_write(SHTP_CH_CONTROL, cmd, sizeof(cmd));
}

static esp_err_t soft_reset_and_wait(void)
{
    const uint8_t reset_cmd = 1;
    esp_err_t err = shtp_write(SHTP_CH_EXECUTABLE, &reset_cmd, 1);
    if (err != ESP_OK) {
        return err;
    }

    vTaskDelay(pdMS_TO_TICKS(300));

    /* Flush advertisements / startup packets. */
    for (int i = 0; i < 20; ++i) {
        uint8_t channel = 0;
        uint8_t cargo[IMU_MAX_PACKET];
        uint16_t cargo_len = 0;
        err = shtp_read(&channel, cargo, &cargo_len, sizeof(cargo));
        if (err == ESP_ERR_NOT_FOUND) {
            break;
        }
        if (err != ESP_OK) {
            continue;
        }
        if (channel == SHTP_CH_EXECUTABLE && cargo_len >= 1 && cargo[0] == 1) {
            ESP_LOGI(TAG, "BNO085 reset complete");
        }
    }
    return ESP_OK;
}

static esp_err_t request_product_id(void)
{
    uint8_t req[2] = {SH2_PRODUCT_ID_REQ, 0};
    esp_err_t err = shtp_write(SHTP_CH_CONTROL, req, sizeof(req));
    if (err != ESP_OK) {
        return err;
    }

    for (int i = 0; i < 30; ++i) {
        uint8_t channel = 0;
        uint8_t cargo[IMU_MAX_PACKET];
        uint16_t cargo_len = 0;
        err = shtp_read(&channel, cargo, &cargo_len, sizeof(cargo));
        if (err == ESP_ERR_NOT_FOUND) {
            vTaskDelay(pdMS_TO_TICKS(10));
            continue;
        }
        if (err != ESP_OK) {
            continue;
        }
        if (channel == SHTP_CH_CONTROL && cargo_len >= 1 && cargo[0] == SH2_PRODUCT_ID_RESP) {
            ESP_LOGI(TAG, "Product ID response received (%u bytes)", cargo_len);
            return ESP_OK;
        }
        if (channel == SHTP_CH_REPORTS && cargo_len > 0) {
            parse_sensor_reports(cargo, cargo_len);
        }
    }
    ESP_LOGW(TAG, "Product ID response not received");
    return ESP_OK; /* Non-fatal — continue enabling reports. */
}

static void imu_poll_task(void *arg)
{
    (void)arg;
    while (true) {
        if (!s_ready) {
            vTaskDelay(pdMS_TO_TICKS(200));
            continue;
        }

        for (int n = 0; n < 8; ++n) {
            uint8_t channel = 0;
            uint8_t cargo[IMU_MAX_PACKET];
            uint16_t cargo_len = 0;
            esp_err_t err = shtp_read(&channel, cargo, &cargo_len, sizeof(cargo));
            if (err == ESP_ERR_NOT_FOUND) {
                break;
            }
            if (err != ESP_OK) {
                ESP_LOGW(TAG, "SHTP read failed: %s", esp_err_to_name(err));
                break;
            }
            if (channel == SHTP_CH_REPORTS && cargo_len > 0) {
                parse_sensor_reports(cargo, cargo_len);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(IMU_POLL_PERIOD_MS));
    }
}

static void i2c_scan_and_log(void)
{
    bool found_any = false;
    for (uint8_t addr = 1; addr < 127; ++addr) {
        esp_err_t err = i2c_master_probe(g_i2c_bus, addr, IMU_XFER_TIMEOUT_MS);
        if (err == ESP_OK) {
            found_any = true;
            ESP_LOGI(TAG, "I2C scan found device at 0x%02X", addr);
        }
    }
    if (!found_any) {
        ESP_LOGW(TAG, "I2C scan found no devices");
    }
}

static esp_err_t probe_bno_address(uint8_t *found_addr)
{
    const uint8_t candidates[2] = {IMU_ADDR_PRIMARY, IMU_ADDR_SECONDARY};
    for (size_t i = 0; i < 2; ++i) {
        esp_err_t err = i2c_master_probe(g_i2c_bus, candidates[i], IMU_XFER_TIMEOUT_MS);
        if (err == ESP_OK) {
            *found_addr = candidates[i];
            ESP_LOGI(TAG, "I2C scan found device at 0x%02X", candidates[i]);
            return ESP_OK;
        }
    }
    return ESP_ERR_NOT_FOUND;
}

esp_err_t imu_init(void)
{
    memset(&s_latest, 0, sizeof(s_latest));
    s_ready = false;
    s_last_ok_us = 0;

    s_lock = xSemaphoreCreateMutex();
    if (s_lock == NULL) {
        ESP_LOGE(TAG, "Mutex create failed");
        return ESP_ERR_NO_MEM;
    }

    i2c_master_bus_config_t bus_cfg = {
        .i2c_port = IMU_I2C_PORT,
        .sda_io_num = IMU_SDA_GPIO,
        .scl_io_num = IMU_SCL_GPIO,
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    esp_err_t err = i2c_new_master_bus(&bus_cfg, &g_i2c_bus);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2c_new_master_bus failed: %s", esp_err_to_name(err));
        return err;
    }

    i2c_scan_and_log();

    err = probe_bno_address(&s_addr);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "BNO085 not found at 0x4A or 0x4B");
        return ESP_ERR_NOT_FOUND;
    }

    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = s_addr,
        .scl_speed_hz = IMU_I2C_HZ,
    };
    err = i2c_master_bus_add_device(g_i2c_bus, &dev_cfg, &s_dev);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2c_master_bus_add_device failed: %s", esp_err_to_name(err));
        return err;
    }

    err = soft_reset_and_wait();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Soft reset failed: %s", esp_err_to_name(err));
        return err;
    }

    (void)request_product_id();

    /* ~50 Hz reports for each enabled sensor. */
    const uint32_t interval_us = 20000;
    err = enable_sensor(SENSOR_LINEAR_ACCEL, interval_us);
    if (err != ESP_OK) {
        return err;
    }
    err = enable_sensor(SENSOR_GYRO_CALIBRATED, interval_us);
    if (err != ESP_OK) {
        return err;
    }
    err = enable_sensor(SENSOR_ROTATION_VECTOR, interval_us);
    if (err != ESP_OK) {
        return err;
    }

    BaseType_t created = xTaskCreate(imu_poll_task, "imu_poll", 4096, NULL, 4, NULL);
    if (created != pdPASS) {
        ESP_LOGE(TAG, "imu_poll task create failed");
        return ESP_ERR_NO_MEM;
    }

    s_ready = true;
    ESP_LOGI(TAG, "BNO085 initialized OK at 0x%02X", s_addr);
    return ESP_OK;
}

esp_err_t imu_read(imu_reading_t *out)
{
    if (out == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    if (!s_ready || s_lock == NULL) {
        memset(out, 0, sizeof(*out));
        out->valid = false;
        return ESP_ERR_TIMEOUT;
    }

    if (xSemaphoreTake(s_lock, pdMS_TO_TICKS(5)) != pdTRUE) {
        memset(out, 0, sizeof(*out));
        out->valid = false;
        return ESP_ERR_TIMEOUT;
    }

    *out = s_latest;
    const int64_t age_us = esp_timer_get_time() - s_last_ok_us;
    xSemaphoreGive(s_lock);

    if (!out->valid || s_last_ok_us == 0 || age_us > 1000000) {
        out->valid = false;
        return ESP_ERR_TIMEOUT;
    }

    return ESP_OK;
}
