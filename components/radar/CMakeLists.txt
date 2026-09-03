idf_component_register(
    SRCS "radar.c"
    INCLUDE_DIRS "."
    REQUIRES esp_driver_i2c imu log freertos esp_timer
)
