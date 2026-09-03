idf_component_register(
    SRCS "event_detector.c"
    INCLUDE_DIRS "."
    REQUIRES freertos log sensor imu
)
