idf_component_register(
    SRCS "sensor.c"
    INCLUDE_DIRS "."
    REQUIRES
        esp_driver_i2c
        esp_timer
        freertos
        log
        imu
)
