idf_component_register(
    SRCS "scorer.c"
    INCLUDE_DIRS "."
    REQUIRES log event_detector
)
