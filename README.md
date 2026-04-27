# J1s-Klipper-Macros

Complete Klipper configuration for the **Snapmaker J1 / J1s** (IDEX 3D printer), including IDEX macros (PRIMARY / COPY / MIRROR / BACKUP), cross-head Z calibration, ADC-based filament sensing, adaptive purge lines with nozzle wipe, and PAUSE / RESUME / START / END overrides.

> ⚠️ **Prerequisite** — This configuration assumes Klipper is **already installed** on your Snapmaker J1/J1s. Please follow **Evil Azrael**'s installation guide before using this repo:
> 👉 **https://wiki.evilazrael.de/en/snapmaker-j1-klipper-installation**
>
> Huge thanks to **Evil Azrael** for his outstanding reverse-engineering and documentation work — none of this would be possible without him. 🙏

> 🇫🇷 Une version française de cette documentation est disponible dans [README_FR.md](README_FR.md).

---

## ✨ Features

- **Full IDEX support** — `PRIMARY`, `COPY`, `MIRROR` modes with clean carriage decoupling and T0/T1 offset management.
- **IDEX Backup mode** — automatic switch to the backup extruder on filament runout; backup head kept at standby temperature to limit ooze while waiting. Activated by plate name.
- **Cross-head Z calibration** — 3-step guided procedure (`CALIBRATE_Z_START` / `SAVE` / `END`) with persistence via `save_variables`.
- **ADC filament sensor** — emulates the stock Snapmaker firmware logic using the PA4 / PA0 optical encoders, auto-pause on jam or auto-switch to backup extruder in BACKUP mode.
- **PT100 nozzle ADC sensor** — conversion table generated for the Snapmaker voltage divider (`Snapmaker J1 Nozzle`).
- **Adaptive purge with nozzle wipe** — volumetric flush then purge line (single-head or synchronized MIRROR), followed by a wipe on the silicone pad before parking.
- **Robust PAUSE / RESUME** — full state save (position, IDEX mode, temperatures, fans) and faithful restore.
- **Filament load/unload** — `LOAD_T0`, `LOAD_T1`, `UNLOAD_T0`, `UNLOAD_T1` macros tuned for the J1s direct drive.
- **MCU fan control** — progressive electronics bay cooling via `temperature_fan`.
- **`G1` override** — blocks Z moves before homing to prevent crashes from slicer-injected G1 Z commands.

## 📁 File layout

```
printer_data/
├── printer.cfg              # Entry point — includes + PID + Z offsets
├── mainsail.cfg             # Mainsail client macros
├── moonraker.conf           # Moonraker config
├── sonar.conf               # WiFi keepalive
├── variables.cfg            # Z offset persistence (auto-generated)
├── backup-mainsail.json     # Mainsail UI backup
│
├── hardware/
│   ├── hardware.cfg         # MCU, steppers, extruders, heaters, fans
│   ├── adc_nozzle_temp.cfg  # Snapmaker PT100 ADC table
│   ├── filament_sensor.cfg  # ADC-based filament sensor (PA4 / PA0)
│   └── MCU_temp_fan.cfg     # Electronics bay fan
│
└── macros/
    ├── macros.cfg           # Logging + homing flag + G1 override
    ├── idex.cfg             # COPY / MIRROR / PRIMARY / BACKUP + T0/T1 + M104/M109/M106/M107
    ├── calibration.cfg      # Cross-head Z calibration + nozzle cleaning
    ├── filament.cfg         # LOAD / UNLOAD T0 / T1
    ├── purge.cfg            # Purge lines with post-purge nozzle wipe
    ├── start_end_pause.cfg  # START_PRINT / END_PRINT / PAUSE / RESUME / CANCEL
    ├── pid.cfg              # PID_BED / PID_EXTRUDER / PID_EXTRUDER1
    └── test_speed.cfg       # IDEX-safe speed/accel test
```

Includes in `printer.cfg` use wildcards:

```ini
[include mainsail.cfg]
[include hardware/*.cfg]
[include macros/*.cfg]
```

## 🚀 Installation

1. **Clone into `~/printer_data/config/`**:
   ```bash
   cd ~/printer_data/config
   git clone https://github.com/<your-user>/J1s-Klipper-Macros.git .
   ```
   ⚠️ Back up your existing config before doing this.

2. **Adapt `hardware/hardware.cfg`** — verify MCU port (`serial:`), pins and TMC currents if your board differs.

3. **Adapt the offsets in `printer.cfg`**:
   - `_J1_CONFIG.right_nozzle_adjust_x` / `_y` — mechanical XY offset between T0 and T1.
   - `Z_OFFSET.t0` / `t1` — defaults at first boot, then overridden by `variables.cfg`.

4. **Restart Klipper**, then run `G28` to verify homing.

5. **Initial calibration** — in this order:
   - `PID_BED`, `PID_EXTRUDER`, `PID_EXTRUDER1`
   - `CALIBRATE_Z_START` → `CALIBRATE_Z_SAVE` → `CALIBRATE_Z_END`

## 🎛️ Main macros

| Macro | Description |
|---|---|
| `START_PRINT` | Heat, home, purge + nozzle wipe, auto IDEX mode from plate name |
| `END_PRINT` | Retract, Z hop, park T0 + T1 |
| `PAUSE` / `RESUME` | Full save/restore (position, IDEX mode, temps, fans) |
| `IDEX_COPY [SPACING=165]` | Enable COPY mode |
| `IDEX_MIRROR` | Enable MIRROR mode |
| `IDEX_PRIMARY` | Back to standard T0 printing |
| `IDEX_BACKUP [BACKUP=0\|1]` | Enable BACKUP mode — auto-switch to backup head on filament runout |
| `T0` / `T1` | Extruder switch with auto source-parking |
| `LOAD_T0` / `LOAD_T1` | Filament load 60mm + 30mm purge |
| `UNLOAD_T0` / `UNLOAD_T1` | Unload 80mm with pre-purge |
| `NOZZLE_CLEAN` / `NOZZLE_CLEAN_END` | Manual nozzle cleaning |
| `CALIBRATE_Z_START/SAVE/END` | Cross-head Z calibration procedure |
| `TEST_SPEED CARRIAGE=0\|1` | Per-carriage safe speed test |
| `FILAMENT_STATUS` | Display ADC sensor state |
| `M412 S0\|1` | Enable/disable filament sensor |

## 🔀 IDEX mode selection from plate name

`START_PRINT` detects the print mode from the `PLATE=` slicer parameter (plate/profile name). Name your slicer plate to contain one of the following keywords:

| Keyword in plate name | Mode |
|---|---|
| *(none)* | PRIMARY — T0 if `T0_TEMP > 0`, T1 if only `T1_TEMP > 0` |
| `copy` | COPY — both heads print the same part side by side |
| `mirror` | MIRROR — both heads print symmetrically about the bed centre |
| `backup` | BACKUP — T0 primary, T1 on standby; auto-switch on T0 runout |
| `backup_t1` | BACKUP — T1 primary, T0 on standby; auto-switch on T1 runout |

In BACKUP mode, the standby head is kept at `print_temp − 70 °C` to limit ooze while waiting. On filament runout, the backup head heats back up to print temperature before continuing — no user intervention required. If the backup head also runs out, the print pauses normally.

## ⚙️ Notable settings

- **`_J1_CONFIG`** (in `printer.cfg`): T1 mechanical offsets (`right_nozzle_adjust_x/y`) and `wipe_on_activate` flag.
- **`Z_OFFSET.t0` / `.t1`**: auto-reloaded from `variables.cfg` 1 s after boot via `[delayed_gcode _LOAD_Z_OFFSETS]`.
- **`_FILAMENT_VARS`**: ADC threshold (`threshold=15`), max consecutive errors (`max_errors=3`), check distance (`check_distance=2.0` mm).
- **`_J1_RUNTIME_STATE`**: temperatures and fans memorized for transparent T0/T1 swaps.

## 🗄️ Mainsail UI backup and restore

The `backup-mainsail.json` file is a complete backup of the Mainsail interface:

- Language and printer name (`Snapmaker J1`, `fr`)
- Theme and colors (`mainsail`, accent `#D41216`)
- **Macro groups**: Calibration, IDEX, Print, Filament, ADC — with per-state visibility (standby / pause / printing)
- **Temperature presets**: PLA Left Extruder, PLA Right Extruder, PLA IDEX, Preheat
- Dashboard layout (3-column widescreen)
- Console and GCode viewer settings

### Restore procedure

1. Download `backup-mainsail.json` from this repository.
2. Open the Mainsail web interface in your browser.
3. Click the **Settings** icon (⚙️) in the top-right corner.
4. In the left menu, go to **"General"** and scroll down to the **Backup** section.
5. Click **"Restore"**, select the `backup-mainsail.json` file and confirm.

> ℹ️ This only affects the Mainsail UI — it does not modify any Klipper configuration files.

## ⚠️ Disclaimer

> These files are provided **without warranty**. A bad configuration can damage your printer. Double-check pin assignments, motor currents and offsets before any movement. The author accepts no liability for any damage.

---

## 📜 License

GPLv3 — see `LICENSE`. Some files (notably `mainsail.cfg`) are redistributed under their original license from the [mainsail-crew](https://github.com/mainsail-crew).

## 🙏 Credits

- **[Evil Azrael](https://wiki.evilazrael.de/en/snapmaker-j1-klipper-installation)** — Snapmaker J1/J1s Klipper installation guide and reverse-engineering work. This project would not exist without him.
- [Klipper](https://github.com/Klipper3d/klipper) — Kevin O'Connor & contributors
- [Mainsail](https://github.com/mainsail-crew/mainsail) — mainsail-crew
