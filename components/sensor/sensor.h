#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"

#define SENSOR_COUNT          6
#define SENSOR_SAMPLE_RATE_HZ 4000

typedef struct {
    uint32_t timestamp_us;
    uint16_t fsr_mv[6];      /* Grass-tared delta mV (0 at rest under turf) */
    uint16_t fsr_raw_mv[6];  /* Absolute ADC mV before tare */
} sensor_sample_t;

extern QueueHandle_t  g_sensor_queue;
extern TaskHandle_t   g_sensor_task_handle;

esp_err_t sensor_init(void);
esp_err_t sensor_start(void);
esp_err_t sensor_stop(void);
void      sensor_task(void *arg);

/** Average resting load for ~2s and treat that as zero. Mat must be at rest. */
void sensor_request_recalibrate(void);
bool sensor_baseline_ready(void);
void sensor_get_baseline_mv(uint16_t out[SENSOR_COUNT]);
