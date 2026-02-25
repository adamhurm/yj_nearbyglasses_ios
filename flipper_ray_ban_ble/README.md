# Ray-Ban BLE Emulator — Flipper Zero FAP

Broadcasts BLE manufacturer-specific advertisements for known smart glasses Company IDs.
**Intended use: testing the NearbyGlasses iOS detection app.**

## What it does

Transmits non-connectable BLE beacons containing Manufacturer Specific Data (AD type 0xFF)
with the Bluetooth SIG Company IDs used by smart glasses manufacturers:

| Label            | Company ID | Manufacturer                       |
|------------------|------------|------------------------------------|
| Meta Tech        | 0x058E     | Meta Platforms Technologies, LLC   |
| Meta Inc.        | 0x01AB     | Meta Platforms, Inc.               |
| Luxottica        | 0x0D53     | EssilorLuxottica (Ray-Ban maker)   |
| Snap Spectacles  | 0x03C2     | Snapchat, Inc.                     |

Beacon parameters: 100–200 ms interval, +6 dBm TX power, random static MAC.

## Controls

| Button | Menu screen          | Advertising screen |
|--------|----------------------|--------------------|
| Up/Down| Navigate list        | —                  |
| OK     | Start advertising    | —                  |
| Back   | Exit app             | Stop + return      |

## Building

### Prerequisites
- [ufbt](https://github.com/flipperdevices/flipperzero-ufbt) (micro Flipper Build Tool)
- Flipper Zero running **firmware 0.83+** (extra beacon API required)

### Build .fap file only
```bash
ufbt fap_ray_ban_ble_emulator
# output: dist/f7-firmware/ray_ban_ble_emulator.fap
```

### Build + deploy + launch over USB
```bash
ufbt launch
# Builds, copies to SD:/apps/Bluetooth/, and opens the app on the Flipper.
```

### Build all FAPs in directory
```bash
ufbt faps
```

### Manual deploy
Copy the built `.fap` to `SD:/apps/Bluetooth/` on your Flipper Zero.

## Notes

- The Flipper Zero BLE radio is shared. If the Flipper is actively connected
  to another BLE device (e.g. Flipper Mobile app), the extra beacon may fail
  to start — disconnect first.
- The advertisement uses a **Random Static** MAC address so it does not
  impersonate any real device's identity.
- The 2-byte manufacturer payload after the Company ID is all zeros — this is
  sufficient to trigger Company ID matching in NearbyGlasses.
- Blue LED blinks while advertising is active.
