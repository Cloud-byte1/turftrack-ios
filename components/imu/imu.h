#pragma once

#include <stdbool.h>
#include "esp_err.h"
#include "driver/i2c_master.h"

/** Shared I2C master bus created by imu_init(). Do not reinitialize it. */
extern i2c_master_bus_handle_t g_i2c_bus;

typedef struct {
    float accel_x, accel_y, accel_z; /* m/s^2 */
    float gyro_x, gyro_y, gyro_z;    /* rad/s */
    float roll, pitch, yaw;          /* degrees */
    bool valid;
} imu_reading_t;

esp_err_t imu_init(void);
esp_err_t imu_read(imu_reading_t *out);
