idf_component_register(
    SRCS "hello_world_main.c"
    INCLUDE_DIRS "."
    REQUIRES
        sensor
        event_detector
        imu
        radar
        scorer
        comms
        freertos
        log
        nvs_flash
)
