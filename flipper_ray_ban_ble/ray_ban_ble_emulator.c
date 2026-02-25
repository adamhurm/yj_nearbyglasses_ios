/**
 * Ray-Ban BLE Emulator for Flipper Zero
 *
 * Broadcasts BLE manufacturer-specific advertisements using the Bluetooth SIG
 * Company IDs assigned to known smart glasses manufacturers. Intended solely
 * for testing the NearbyGlasses iOS detection app without owning the physical
 * hardware.
 *
 * Uses the Flipper Zero Extra Beacon API (furi_hal_bt_extra_beacon_*) to
 * transmit non-connectable BLE advertisements.
 *
 * Flipper Zero screen: 128x64 pixels
 */

#include <furi.h>
#include <furi_hal.h>
#include <furi_hal_bt.h>
#include <gui/gui.h>
#include <gui/elements.h>
#include <input/input.h>
#include <notification/notification.h>
#include <notification/notification_messages.h>

#define TAG "RayBanBLE"

// ---------------------------------------------------------------------------
// Device profiles — each entry corresponds to one known smart glasses Company ID
// ---------------------------------------------------------------------------

typedef struct {
    const char* short_name;  // Fits in the menu list
    const char* long_name;   // Shown on the advertising screen
    const char* cid_str;     // Human-readable CID
    uint8_t     cid_lo;      // Company ID low byte (little-endian BLE)
    uint8_t     cid_hi;      // Company ID high byte (little-endian BLE)
} DeviceProfile;

typedef enum {
    DeviceMeta2 = 0,   // 0x058E  Meta Platforms Technologies, LLC
    DeviceMeta1,       // 0x01AB  Meta Platforms, Inc.
    DeviceLuxottica,   // 0x0D53  EssilorLuxottica (manufactures Ray-Ban)
    DeviceSnap,        // 0x03C2  Snapchat, Inc. (Snap Spectacles)
    DeviceCount,
} DeviceIndex;

static const DeviceProfile kDevices[DeviceCount] = {
    [DeviceMeta2]     = {"Meta Tech",      "Meta Platforms Tech",  "0x058E", 0x8E, 0x05},
    [DeviceMeta1]     = {"Meta Inc.",      "Meta Platforms, Inc.", "0x01AB", 0xAB, 0x01},
    [DeviceLuxottica] = {"Luxottica",      "EssilorLuxottica",     "0x0D53", 0x53, 0x0D},
    [DeviceSnap]      = {"Snap Spectacles","Snapchat, Inc.",        "0x03C2", 0xC2, 0x03},
};

// Random-looking static MAC address used for the emulated device.
// GapAddressTypeRandom so no real device is impersonated.
static const uint8_t kEmulatedMac[EXTRA_BEACON_MAC_ADDR_SIZE] = {0x5E, 0x9A, 0x3C, 0x1D, 0x87, 0x42};

// ---------------------------------------------------------------------------
// App state
// ---------------------------------------------------------------------------

typedef enum {
    ScreenMenu,
    ScreenAdvertising,
} AppScreen;

typedef struct {
    AppScreen    screen;
    DeviceIndex  selected;
    bool         advertising;

    Gui*              gui;
    ViewPort*         view_port;
    FuriMessageQueue* event_queue;
    NotificationApp*  notification;
} App;

// ---------------------------------------------------------------------------
// BLE advertisement helpers
// ---------------------------------------------------------------------------

/**
 * Builds a minimal BLE advertisement payload:
 *   AD[0]: Flags — LE General Discoverable, BR/EDR Not Supported
 *   AD[1]: Manufacturer Specific Data — Company ID (little-endian) + 2-byte payload
 *
 * CoreBluetooth parses bytes [0..1] of Manufacturer Specific Data as the
 * Company ID (UInt16, little-endian). That's exactly what we place at cid_lo/cid_hi.
 *
 * Max BLE legacy advertisement: 31 bytes. This packet is 9 bytes.
 */
static uint8_t build_adv_data(const DeviceProfile* p, uint8_t out[EXTRA_BEACON_MAX_DATA_SIZE]) {
    uint8_t i = 0;

    // AD Element: Flags (3 bytes)
    out[i++] = 0x02;  // Length
    out[i++] = 0x01;  // Type: Flags
    out[i++] = 0x06;  // LE General Discoverable | BR/EDR Not Supported

    // AD Element: Manufacturer Specific Data (6 bytes)
    out[i++] = 0x05;      // Length (type + 2-byte CID + 2-byte payload)
    out[i++] = 0xFF;      // Type: Manufacturer Specific
    out[i++] = p->cid_lo; // Company ID low byte
    out[i++] = p->cid_hi; // Company ID high byte
    out[i++] = 0x00;      // Payload byte 1 (placeholder)
    out[i++] = 0x00;      // Payload byte 2 (placeholder)

    return i;
}

static void ble_start(App* app) {
    const DeviceProfile* p = &kDevices[app->selected];

    // Stop any running beacon first
    furi_hal_bt_extra_beacon_stop();

    // Set advertisement data
    uint8_t adv_data[EXTRA_BEACON_MAX_DATA_SIZE];
    uint8_t adv_len = build_adv_data(p, adv_data);
    furi_hal_bt_extra_beacon_set_data(adv_data, adv_len);

    // Configure beacon: 100-200ms interval, all channels, max power, random static MAC
    GapExtraBeaconConfig cfg = {
        .min_adv_interval_ms = 100,
        .max_adv_interval_ms = 200,
        .adv_channel_map     = GapAdvChannelMapAll,
        .adv_power_level     = GapAdvPowerLevel_6dBm,
        .address_type        = GapAddressTypeRandom,
    };
    memcpy(cfg.address, kEmulatedMac, EXTRA_BEACON_MAC_ADDR_SIZE);
    furi_hal_bt_extra_beacon_set_config(&cfg);

    bool ok = furi_hal_bt_extra_beacon_start();
    app->advertising = ok;

    FURI_LOG_I(TAG, "BLE beacon %s - %s (%s)", ok ? "started" : "FAILED", p->long_name, p->cid_str);

    if(ok) {
        notification_message(app->notification, &sequence_blink_start_blue);
    }
}

static void ble_stop(App* app) {
    furi_hal_bt_extra_beacon_stop();
    app->advertising = false;
    notification_message(app->notification, &sequence_blink_stop);
    FURI_LOG_I(TAG, "BLE beacon stopped");
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

static void draw_callback(Canvas* canvas, void* ctx) {
    App* app = ctx;
    canvas_clear(canvas);
    canvas_set_color(canvas, ColorBlack);

    if(app->screen == ScreenMenu) {
        // Title bar
        canvas_set_font(canvas, FontPrimary);
        canvas_draw_str(canvas, 2, 10, "Ray-Ban BLE Emulator");
        canvas_draw_line(canvas, 0, 12, 128, 12);

        // Device list
        canvas_set_font(canvas, FontSecondary);
        for(int i = 0; i < DeviceCount; i++) {
            uint8_t y = 24 + i * 10;
            if(i == (int)app->selected) {
                canvas_draw_box(canvas, 0, y - 8, 128, 10);
                canvas_set_color(canvas, ColorWhite);
                canvas_draw_str(canvas, 4, y, ">");
                canvas_draw_str(canvas, 12, y, kDevices[i].short_name);
                canvas_draw_str(canvas, 80, y, kDevices[i].cid_str);
                canvas_set_color(canvas, ColorBlack);
            } else {
                canvas_draw_str(canvas, 12, y, kDevices[i].short_name);
                canvas_draw_str(canvas, 80, y, kDevices[i].cid_str);
            }
        }

        // Footer
        canvas_draw_line(canvas, 0, 54, 128, 54);
        canvas_set_font(canvas, FontSecondary);
        canvas_draw_str(canvas, 2, 63, "[Ok] Advertise  [Bk] Exit");

    } else {  // ScreenAdvertising
        const DeviceProfile* p = &kDevices[app->selected];
        char buf[32];

        // Title + filled dot indicator
        canvas_set_font(canvas, FontPrimary);
        canvas_draw_str(canvas, 2, 10, "Broadcasting...");
        canvas_draw_disc(canvas, 122, 6, 4);

        canvas_draw_line(canvas, 0, 12, 128, 12);

        // Info
        canvas_set_font(canvas, FontSecondary);
        canvas_draw_str(canvas, 2, 24, p->long_name);

        snprintf(buf, sizeof(buf), "Company ID: %s", p->cid_str);
        canvas_draw_str(canvas, 2, 34, buf);

        snprintf(
            buf, sizeof(buf), "MAC: %02X:%02X:%02X:%02X:%02X:%02X",
            kEmulatedMac[0], kEmulatedMac[1], kEmulatedMac[2],
            kEmulatedMac[3], kEmulatedMac[4], kEmulatedMac[5]);
        canvas_draw_str(canvas, 2, 44, buf);

        canvas_draw_str(canvas, 2, 54, "100-200ms  +6dBm  All Ch");

        // Footer
        canvas_draw_line(canvas, 0, 56, 128, 56);
        canvas_draw_str(canvas, 2, 64, "[Back] Stop");
    }
}

// ---------------------------------------------------------------------------
// Input handling
// ---------------------------------------------------------------------------

static void input_callback(InputEvent* event, void* ctx) {
    App* app = ctx;
    furi_message_queue_put(app->event_queue, event, FuriWaitForever);
}

// ---------------------------------------------------------------------------
// Application lifecycle
// ---------------------------------------------------------------------------

static App* app_alloc() {
    App* app = malloc(sizeof(App));
    app->screen      = ScreenMenu;
    app->selected    = DeviceMeta2;
    app->advertising = false;

    app->event_queue  = furi_message_queue_alloc(8, sizeof(InputEvent));
    app->notification = furi_record_open(RECORD_NOTIFICATION);

    app->view_port = view_port_alloc();
    view_port_draw_callback_set(app->view_port, draw_callback, app);
    view_port_input_callback_set(app->view_port, input_callback, app);

    app->gui = furi_record_open(RECORD_GUI);
    gui_add_view_port(app->gui, app->view_port, GuiLayerFullscreen);

    return app;
}

static void app_free(App* app) {
    if(app->advertising) ble_stop(app);

    gui_remove_view_port(app->gui, app->view_port);
    furi_record_close(RECORD_GUI);
    view_port_free(app->view_port);

    furi_record_close(RECORD_NOTIFICATION);
    furi_message_queue_free(app->event_queue);

    free(app);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

int32_t ray_ban_ble_app(void* p) {
    UNUSED(p);

    App* app = app_alloc();
    InputEvent event;
    bool running = true;

    while(running) {
        if(furi_message_queue_get(app->event_queue, &event, 100) != FuriStatusOk) {
            view_port_update(app->view_port);
            continue;
        }

        if(event.type != InputTypePress && event.type != InputTypeRepeat) continue;

        if(app->screen == ScreenMenu) {
            switch(event.key) {
            case InputKeyUp:
                app->selected = (app->selected == 0) ? DeviceCount - 1 : app->selected - 1;
                break;
            case InputKeyDown:
                app->selected = (app->selected + 1) % DeviceCount;
                break;
            case InputKeyOk:
                ble_start(app);
                if(app->advertising) app->screen = ScreenAdvertising;
                break;
            case InputKeyBack:
                running = false;
                break;
            default:
                break;
            }
        } else {
            if(event.key == InputKeyBack) {
                ble_stop(app);
                app->screen = ScreenMenu;
            }
        }

        view_port_update(app->view_port);
    }

    app_free(app);
    return 0;
}
