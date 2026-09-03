#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "ble.h"
#include "radar.h"
#include "esp_log.h"
#include "host/ble_hs.h"
#include "host/ble_uuid.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

static const char *TAG = "ble";
static uint8_t s_own_addr_type;
static uint16_t s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_swing_value_handle;

bool g_ble_connected;

static const ble_uuid16_t s_service_uuid = BLE_UUID16_INIT(0xAB12);
static const ble_uuid16_t s_swing_uuid = BLE_UUID16_INIT(0xAB13);

static int ble_gatt_access_cb(uint16_t conn_handle, uint16_t attr_handle,
    struct ble_gatt_access_ctxt *ctxt, void *arg)
{
return BLE_ATT_ERR_READ_NOT_PERMITTED;
}

static const struct ble_gatt_svc_def s_gatt_services[] = {
{
.type = BLE_GATT_SVC_TYPE_PRIMARY,
.uuid = &s_service_uuid.u,
.characteristics = (struct ble_gatt_chr_def[]) {
{
.uuid       = &s_swing_uuid.u,
.access_cb  = ble_gatt_access_cb,
.val_handle = &s_swing_value_handle,
.flags      = BLE_GATT_CHR_F_NOTIFY,
},
{ 0 }
},
},
{ 0 }
};

static void start_advertising(void);

static int gap_event(struct ble_gap_event *event, void *arg)
{
    (void)arg;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            struct ble_gap_upd_params params = {
                .itvl_min = 12,
                .itvl_max = 24,
                .latency = 0,
                .supervision_timeout = 400,
                .min_ce_len = 0,
                .max_ce_len = 0,
            };
            s_conn_handle = event->connect.conn_handle;
            g_ble_connected = true;
            int rc = ble_gap_update_params(s_conn_handle, &params);
            if (rc != 0) {
                ESP_LOGW(TAG, "Connection parameter request failed: %d", rc);
            }
            ESP_LOGI(TAG, "iPhone connected");
        } else {
            start_advertising();
        }
        return 0;

    case BLE_GAP_EVENT_DISCONNECT:
        g_ble_connected = false;
        s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
        ESP_LOGI(TAG, "Disconnected; restarting advertising");
        start_advertising();
        return 0;

    case BLE_GAP_EVENT_ADV_COMPLETE:
        start_advertising();
        return 0;

    default:
        return 0;
    }
}

static void start_advertising(void)
{
    /* Keep ADV lean: flags + 16-bit service UUID (Web Bluetooth filters on this). */
    struct ble_hs_adv_fields fields = {0};
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.uuids16 = (ble_uuid16_t *)&s_service_uuid;
    fields.num_uuids16 = 1;
    fields.uuids16_is_complete = 1;

    int rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "Advertising data setup failed: %d", rc);
        return;
    }

    /* Put the readable name in the scan response. */
    struct ble_hs_adv_fields rsp = {0};
    const char *name = ble_svc_gap_device_name();
    rsp.name = (const uint8_t *)name;
    rsp.name_len = strlen(name);
    rsp.name_is_complete = 1;
    rc = ble_gap_adv_rsp_set_fields(&rsp);
    if (rc != 0) {
        ESP_LOGE(TAG, "Scan response setup failed: %d", rc);
        return;
    }

    struct ble_gap_adv_params params = {
        .conn_mode = BLE_GAP_CONN_MODE_UND,
        .disc_mode = BLE_GAP_DISC_MODE_GEN,
    };
    rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER,
                           &params, gap_event, NULL);
    if (rc != 0 && rc != BLE_HS_EALREADY) {
        ESP_LOGE(TAG, "Advertising start failed: %d", rc);
    }
}

static void ble_on_sync(void)
{
    int rc = ble_hs_id_infer_auto(0, &s_own_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "Address inference failed: %d", rc);
        return;
    }
    start_advertising();
    ESP_LOGI(TAG, "Advertising as GolfMat");
}

static void ble_host_task(void *param)
{
    (void)param;
    nimble_port_run();
    nimble_port_freertos_deinit();
}

void ble_init(void)
{
    int rc = nimble_port_init();
    if (rc != 0) {
        ESP_LOGE("ble", "nimble_port_init failed with rc=%d", rc);
        return;
    }
    ble_svc_gap_init();
    ble_svc_gatt_init();
    rc = ble_svc_gap_device_name_set("GolfMat");
    if (rc != 0) {
        ESP_LOGE("ble", "gap_device_name_set failed: %d", rc);
        return;
    }
    
    rc = ble_gatts_count_cfg(s_gatt_services);
    if (rc != 0) {
        ESP_LOGE("ble", "gatts_count_cfg failed: %d", rc);
        return;
    }
    
    rc = ble_gatts_add_svcs(s_gatt_services);
    if (rc != 0) {
        ESP_LOGE("ble", "gatts_add_svcs failed: %d", rc);
        return;
    }

    // Register sync callback — this fires when NimBLE stack is ready
    // NEVER call start_advertising() before this fires
    ble_hs_cfg.sync_cb = ble_on_sync;

    // Start the NimBLE host task on Core 0
    nimble_port_freertos_init(ble_host_task);

    ESP_LOGI(TAG, "BLE init complete");
}

static int16_t clamp_i16(float value)
{
    if (value > 32767.0f) {
        return 32767;
    }
    if (value < -32768.0f) {
        return -32768;
    }
    return (int16_t)lroundf(value);
}

static bool fill_swing_packet(ble_swing_packet_t *packet,
                              swing_event_t *event,
                              swing_score_t *score)
{
    if (packet == NULL || event == NULL || score == NULL) {
        return false;
    }

    memset(packet, 0, sizeof(*packet));
    packet->timestamp_ms = event->timestamp_us / 1000U;
    packet->impact_duration_us = event->impact_duration_us;
    packet->impact_zone = event->impact_zone;
    packet->impact_quality = score->impact_quality;
    packet->contact_zone_label = score->contact_zone_label;
    packet->estimated_distance_m = score->estimated_distance_m;
    packet->consistency_hint = score->consistency_hint;
    packet->flags = event->flags;
    packet->strike_zone = (uint8_t)event->strike_zone;
    packet->strike_direction = (uint8_t)event->strike_direction;
    packet->heel_pressure_pct = event->heel_pressure_pct;
    packet->center_pressure_pct = event->center_pressure_pct;
    packet->toe_pressure_pct = event->toe_pressure_pct;
    packet->direction_penalty = score->direction_penalty;
    memcpy(packet->fsr_peak, event->fsr_peak, sizeof(packet->fsr_peak));

    if (event->imu.valid) {
        const float g = 9.80665f;
        const float rad_to_mdeg = 180.0f / (float)M_PI * 1000.0f;
        packet->accel_x_mg = clamp_i16((event->imu.accel_x / g) * 1000.0f);
        packet->accel_y_mg = clamp_i16((event->imu.accel_y / g) * 1000.0f);
        packet->accel_z_mg = clamp_i16((event->imu.accel_z / g) * 1000.0f);
        packet->gyro_x_mdps = clamp_i16(event->imu.gyro_x * rad_to_mdeg);
        packet->gyro_y_mdps = clamp_i16(event->imu.gyro_y * rad_to_mdeg);
        packet->gyro_z_mdps = clamp_i16(event->imu.gyro_z * rad_to_mdeg);
        packet->yaw_deg10 = clamp_i16(event->imu.yaw * 10.0f);
    }

    radar_reading_t radar = {0};
    if (radar_read(&radar) == ESP_OK && radar.valid) {
        packet->radar_speed_mph10 = clamp_i16(radar.speed_mph * 10.0f);
        packet->radar_distance_mm = clamp_i16((float)radar.presence_distance_mm);
        packet->radar_intra_score =
            radar.intra_score > UINT16_MAX ? UINT16_MAX : (uint16_t)radar.intra_score;
        /* Valid for BLE speed only when estimated motion is non-zero. */
        packet->radar_valid = (radar.speed_mph > 0.0f) ? 1 : 0;
        if (packet->radar_valid == 0) {
            packet->radar_speed_mph10 = 0;
        }
    } else {
        packet->radar_speed_mph10 = 0;
        packet->radar_distance_mm = 0;
        packet->radar_intra_score = 0;
        packet->radar_valid = 0;
    }

    return true;
}

void serial_send_swing_result(swing_event_t *event, swing_score_t *score)
{
    ble_swing_packet_t packet;
    if (!fill_swing_packet(&packet, event, score)) {
        return;
    }

    const uint8_t *bytes = (const uint8_t *)&packet;
    printf("GMSWING ");
    for (size_t i = 0; i < sizeof(packet); ++i) {
        printf("%02X", bytes[i]);
    }
    printf("\n");
    fflush(stdout);
}

void ble_send_swing_result(swing_event_t *event, swing_score_t *score)
{
    if (!g_ble_connected) {
        return;
    }

    ble_swing_packet_t packet;
    if (!fill_swing_packet(&packet, event, score)) {
        return;
    }

    struct os_mbuf *om = ble_hs_mbuf_from_flat(&packet, sizeof(packet));
    if (om == NULL) {
        ESP_LOGW(TAG, "Notification buffer unavailable");
        return;
    }
    int rc = ble_gatts_notify_custom(s_conn_handle, s_swing_value_handle, om);
    if (rc != 0) {
        ESP_LOGW(TAG, "Notification failed: %d", rc);
    }
}
