# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Klipper configuration for the **Snapmaker J1 / J1s** IDEX 3D printer. Files are deployed to `~/printer_data/config/` on the printer host (Raspberry Pi / Snapmaker Linux board). There is no build or test step — changes take effect after a Klipper restart (`FIRMWARE_RESTART` or `RESTART` from Mainsail/KlipperScreen).

## File loading order

`printer.cfg` is the entry point and loads everything else via wildcards:

```ini
[include mainsail.cfg]
[include hardware/*.cfg]
[include macros/*.cfg]
```

`hardware/*.cfg` defines all physical hardware (MCU, steppers, extruders, heaters, fans) — including `MCU_temp_fan.cfg` (enclosure fan, always active).  
`macros/*.cfg` defines all GCode macros. Load order within each wildcard glob is alphabetical.

Optional extras are activated by explicit includes in `printer.cfg`:

```ini
#[include Extras/MMB_cubic.cfg]     # BTT MMB Cubic secondary MCU (RP2040)
#[include Extras/MMB_aux_fan.cfg]   # Auxiliary fan on MMB Cubic FAN0 (gpio8) — requires MMB_cubic.cfg
#[include Extras/adxl345_fysetc_v1.cfg]  # FYSETC v1 ADXL345 input shaper
```

## Architecture: optional Extras files

| File | Purpose |
|---|---|
| `hardware/MCU_temp_fan.cfg` | Enclosure fan on PC6, auto temp-controlled via PID (target 45 °C). Always loaded via `hardware/*.cfg`. |
| `Extras/MMB_cubic.cfg` | BTT MMB Cubic V1.0 secondary MCU (`[mcu mmb]`, serial `usb-Klipper_rp2040_5044340310ABD01C-if00`). Provides `mmb_fan1` (gpio7) and `mmb_fan2` (gpio6). Requires 24V DCIN + USB. RP2040 firmware must match J1s Klipper version. |
| `Extras/MMB_aux_fan.cfg` | Auxiliary fan on MMB Cubic FAN0 (mmb:gpio8) as `[fan_generic aux_fan]`. Must be loaded **after** `MMB_cubic.cfg`. |
| `Extras/adxl345_fysetc_v1.cfg` | FYSETC Portable Input Shaper v1 (ADXL345 via USB RP2040, serial `usb-Klipper_rp2040_E66160F4236A8F37-if00`). |

> **MMB Cubic firmware**: compiled on the J1s by temporarily uncommenting `source "src/rp2040/Kconfig"` in `~/klipper/src/Kconfig`, then `make KCONFIG_CONFIG=.config olddefconfig && make`. The compiled `out/klipper.uf2` is flashed by copying it to the RP2040 bootloader drive (device enters PICOBOOT mode when `flash_usb.py` triggers it). Re-comment the Kconfig line after compiling to restore the snapmakerj1 fork state.

## Architecture: key variables and state macros

Several `[gcode_macro]` blocks act as pure state containers (their `gcode:` is a no-op):

| Macro | Purpose |
|---|---|
| `_J1_CONFIG` | Static mechanical offsets: `right_nozzle_adjust_x/y` (T1 vs T0 XY), `wipe_on_activate` flag |
| `_Z_OFFSET` | Live Z offsets `t0`/`t1`; loaded 1 s after boot by `[delayed_gcode _LOAD_Z_OFFSETS]` from `variables.cfg` |
| `_J1_RUNTIME_STATE` | In-flight temperatures and fan speeds for both heads; updated by every M104/M109/M106 call |
| `_HOMED` | `ready=0/1` flag set by `START_PRINT`; guards the G1 override from blocking manual jogs |
| `_PAUSE_STATE` | Full machine snapshot (XY Z E, gcode offsets X/Y/Z, IDEX mode, temps, fans) saved at PAUSE time for RESUME |
| `_BACKUP_STATE` | BACKUP mode state: `enabled`, `primary` (0/1), `backup` (0/1), `switched` (0/1 — whether the auto-switch already fired) |
| `_FILAMENT_VARS` | ADC sensor tunables: `threshold`, `max_errors`, `check_distance`, filament densities |

## Architecture: GCode overrides

Several standard commands are renamed and replaced:

| Override | Replaces | Why |
|---|---|---|
| `G1` | `G1.1` | Blocks any `Z` parameter when `_HOMED.ready=0` AND Z not yet homed — prevents slicer-injected `G1 Z` from crashing the head before `START_PRINT` |
| `M104` | `M104.1` | Intercepts target temperature and stores it in `_J1_RUNTIME_STATE.left_temp` / `right_temp` for transparent T0/T1 switching |
| `M109` | `M109.1` | Same as M104 but blocking |
| `M106` | — (new) | Routes part-fan commands to `left_part_fan` / `right_part_fan` based on active IDEX mode and which heads are hot |
| `M107` | — (new) | Delegates to `M106 S0` |
| `PAUSE` | `PAUSE_BASE` | Full state save + Z-hop + park at X edge |
| `RESUME` | `RESUME_BASE` | State restore + IDEX mode re-activation |
| `CANCEL_PRINT` | `CANCEL_PRINT_BASE` | Park both heads, heaters off, reset state |
| `M600` | — (new) | Filament change — delegates to `PAUSE` |

> When writing macros that set temperature, always use `M104.1` / `M109.1` (the renamed originals) if you do **not** want the temp stored in `_J1_RUNTIME_STATE`. Use `M104` / `M109` if the temp should be remembered across T0/T1 switches.

## Architecture: PAUSE / RESUME internals

**Critical constraint**: `[pause_resume]` must have `recover_velocity` set to a **non-zero** value (currently `50`). In recent Klipper, `RESUME_BASE` always emits `RESTORE_GCODE_STATE NAME=PAUSE_STATE MOVE=1 MOVE_SPEED=<value>` — `MOVE_SPEED=0` is a fatal error.

**PAUSE in COPY/MIRROR mode**: after `_IDEX_DECOUPLE`, T1 stays at its printing position (T0_X + spacing) — it is NOT automatically parked. The PAUSE macro explicitly parks T1 to the right edge (`position_max - t1_x_off - 10`) immediately after the Z hop (Z axis is shared so T1 is already at safe height). Only then does T0 park at the left edge.

**RESUME macro order** (non-negotiable):
1. `RESUME_BASE` **first** — Klipper sets `is_paused=False` and calls `RESTORE_GCODE_STATE NAME=PAUSE_STATE` which restores gcode offsets (T0/T1 Z offsets) saved by `PAUSE_BASE`. The head moves back to the park position (already there — effectively a no-op move).
2. IDEX mode restore (COPY/MIRROR if needed).
3. Filament re-injection.
4. XY move to saved print position.
5. Z lower to saved print height.

If `RESUME_BASE` is called **after** the Z move, Klipper re-raises the head to the park position, undoing the Z restore.

**Gcode offset save/restore**: positions in `_PAUSE_STATE` are in gcode space (with T1 Z offset active, e.g. `-4.46`). `RESTORE_GCODE_STATE` inside `RESUME_BASE` re-applies the offset before our XY/Z moves. Do not add a manual `SET_GCODE_OFFSET` in RESUME — it would double-apply.

## Architecture: T0 / T1 switching

`_SWITCH_TO_EXTRUDER` (called internally by `T0` and `T1`) applies the correct `SET_GCODE_OFFSET` and `ACTIVATE_EXTRUDER` for the target head. It reads offsets from `_J1_CONFIG` and `Z_OFFSET`.

`AUTOPARK` parameter on `T0`/`T1` (default `1`): when `1`, the departing head parks at its X edge before the switch. Pass `AUTOPARK=0` in `START_PRINT` and `RESUME` to suppress the park move (head is already positioned or position is managed externally).

## Architecture: IDEX mode transitions

COPY and MIRROR modes require a strict carriage sequencing that is **not obvious from Klipper docs**:

1. Decouple both carriages (`SET_DUAL_CARRIAGE CARRIAGE=x MODE=PRIMARY` for each + `SYNC_EXTRUDER_MOTION` reset).
2. Move T0 to its start position with `CARRIAGE=0 MODE=PRIMARY` active.
3. Move T1 to its start position with `CARRIAGE=1 MODE=PRIMARY` active.
4. **Set C0 back as PRIMARY** — Klipper raises `Must activate another carriage as PRIMARY first` if C1 is the active PRIMARY when you try to switch it to COPY/MIRROR.
5. Then set `CARRIAGE=1 MODE=COPY` or `CARRIAGE=1 MODE=MIRROR` and sync the extruder.
6. Apply `SET_GCODE_OFFSET Z=…` only **after** COPY/MIRROR activation.

`_IDEX_DECOUPLE` handles the decouple step and ends on the currently active carriage to preserve move context.

## Architecture: Z offset persistence

`Z_OFFSET.t0` and `Z_OFFSET.t1` are kept in sync (T1 is levelled mechanically to match T0). Only `z_offset_t0` is persisted via `SAVE_VARIABLE`. On boot, `[delayed_gcode _LOAD_Z_OFFSETS]` fires after 1 s and sets both variables. On first boot the default from `printer.cfg` is written to `variables.cfg`.

## Architecture: START_PRINT IDEX mode detection

`START_PRINT` infers the print mode from the `PLATE=` parameter (plate name from the slicer):
- Contains `copy` → `IDEX_COPY`
- Contains `mirror` → `IDEX_MIRROR`
- Contains `backup` → `IDEX_BACKUP BACKUP=1` (T0 primary, T1 backup)
- Contains `backup_t1` → `IDEX_BACKUP BACKUP=0` (T1 primary, T0 backup)
- Otherwise PRIMARY (T0 if `T0_TEMP>0`, T1 if only `T1_TEMP>0`)

## Architecture: calibration workflow

`CALIBRATE_Z_START` → `CALIBRATE_Z_SAVE` → `CALIBRATE_Z_END` is the 3-step Z offset procedure:
1. `CALIBRATE_Z_START TEMP=200` — activates T0, heats both heads (T1 preheats to 140 °C in background), homes, wipes T0, then positions T0 at bed centre at gcode Z=0. Paper-test the gap and adjust the Z offset with `SET_GCODE_OFFSET Z=<value>` or via KlipperScreen's Z offset panel. **Do not use `TESTZ`** — it only works inside a `MANUAL_PROBE` session.
2. `CALIBRATE_Z_SAVE` — reads `printer.gcode_move.homing_origin.z` (the current gcode Z offset set in step 1) and persists it as `z_offset_t0`. Then activates T1, waits for it to reach temperature, wipes it, and positions T1 at bed centre for mechanical adjustment.
3. `CALIBRATE_Z_END` — T1 is adjusted mechanically via the set-screw (no software offset for T1). Parks both heads and homes.

`_Z_OFFSET.t0` and `_Z_OFFSET.t1` are always kept identical. Only `t0` is persisted.

**`_WIPE_NOZZLE` constraint**: the caller must have the correct carriage active as PRIMARY before calling `_WIPE_NOZZLE T=0` or `T=1`. The macro issues G1 moves without switching carriages — if T1 is PRIMARY when `_WIPE_NOZZLE T=0` is called, T1 will try to reach X=10 which is blocked by `safe_distance: 21` if T0 is at X=0, causing "Move out of range".

## Deployment

To push a changed config file directly to the printer over the local network (PuTTY `pscp` required):
```bash
"/c/Program Files/PuTTY/pscp" -pw <password> -batch macros/start_end_pause.cfg pi@<printer-ip>:/home/pi/printer_data/config/macros/start_end_pause.cfg
```
After uploading, send `FIRMWARE_RESTART` from Mainsail or KlipperScreen to apply the changes.

**MCU firmware flash** (GD32F307): use `~/klipper/scripts/j1_flash_firmware.py`. **Stop Klipper first** — if Klipper service is running it fights for `/dev/ttyMSM1` at 250000 baud and corrupts the SACP handshake at 115200 baud, causing Phase 1 timeout.
```bash
sudo systemctl stop klipper
python3 ~/klipper/scripts/j1_flash_firmware.py --port /dev/ttyMSM1 ~/klipper/out/klipper.bin
sudo systemctl start klipper
```
The Snapmaker bootloader at `0x08000000` enters SACP flash mode automatically when the status page at `0x080fd000` is not `APPLICATION_STATUS_APP_RUNNABLE` (0xaa05). After a failed flash, the status is typically left in an intermediate state so the bootloader stays in flash mode — but only if Klipper is not competing for the port.

## Logging conventions

- `DBG_LOG MSG="…"` → debug-level, prefixed `-- `
- `IMP_LOG MSG="…"` → important/user-visible, prefixed `!! `

## Files not to modify blindly

- The `#*# <--- SAVE_CONFIG --->` block at the bottom of `printer.cfg` is auto-generated by Klipper and overwritten on every `SAVE_CONFIG`. Do not add anything below it.
- `variables.cfg` is auto-generated by `SAVE_VARIABLE`. Do not edit by hand while Klipper is running.
- `mainsail.cfg` is from upstream [mainsail-crew](https://github.com/mainsail-crew/mainsail) — prefer not to modify it directly.

## Hardware notes

- MCU: `/dev/ttyMSM1` at 250000 baud — Snapmaker J1/J1s onboard STM32.
- Nozzle temperature sensor: custom `Snapmaker J1 Nozzle` ADC type (PT100 via voltage divider, table defined in `hardware/adc_nozzle_temp.cfg`). `voltage_offset` in `hardware.cfg` can fine-tune reading (±0.035 V ≈ ±5 °C).
- Part fans are `fan_generic` (not `[fan]`) so they must be driven via `SET_FAN_SPEED` — they are never the "default fan" for `M106` without the override.
- `safe_distance: 21` on `[dual_carriage]` is the physical minimum gap between T0 and T1 carriages.
