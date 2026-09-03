idf_component_register(
    SRCS "ble.c"
    INCLUDE_DIRS "."
    REQUIRES bt log freertos event_detector scorer radar
)
