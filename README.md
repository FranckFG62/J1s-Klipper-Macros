# J1s-Klipper-Macros

Complete Klipper configuration for the **Snapmaker J1 / J1s** (IDEX 3D printer), including IDEX macros (PRIMARY / COPY / MIRROR / BACKUP), Z calibration, ADC-based filament sensing.

> ⚠️ **Prerequisite** — This configuration assumes Klipper is **already installed** on your Snapmaker J1/J1s. Please follow **Evil Azrael**'s installation guide before using this repo:
> 👉 **https://wiki.evilazrael.de/en/snapmaker-j1-klipper-installation**
>
> Huge thanks to **Evil Azrael** for his outstanding reverse-engineering and documentation work — none of this would be possible without him. 🙏

> 🇫🇷 Une version française de cette documentation est disponible dans [README_FR.md](README_FR.md).

---
## 🚀 Installation

1. **Clone into `~/printer_data/config/`**:
   ```bash
   cd ~/printer_data/config
   git clone https://github.com/FranckFG62/J1s-Klipper-Macros.git .
   ```
   ⚠️ Back up your existing config before doing this.

2. **Adapt the offsets in `printer.cfg`**:
   - `_J1_CONFIG.right_nozzle_adjust_x` / `_y` — mechanical XY offset between T0 and T1.

     Automatic XY offset calibration is not implemented — this step is manual.

     Use the model from the downloaded package. It is an integrated version of the XY calibration by «LMaker» available at https://www.printables.com/model/129617-offset-xy-dual-extruder-idex-calibration. You will also find instructions on how to interpret the results.

     In short:

     Print the bottom part of the model with the left extruder and the top part with the right extruder.
     On the printed model, you will see two axes with bars.

     On each axis, find the perfectly aligned bar, on the positive or negative side. Multiply the index (starting from 0) of the corresponding bar by 0.1 to get the offset. For example, if the third negative bar matches, the calculation is: (3 - 1) * -0.1 = -0.2.

     Edit `printer.cfg`. Find the lines `variable_right_nozzle_adjust_x: 0` and `variable_right_nozzle_adjust_y: 0`.
     Subtract the calculated offset from the current value.

     Save, restart Klipper, print again — the first bars on each axis should now be aligned.

3. **Initial calibration** — in this order:
   - `PID_BED`, `PID_EXTRUDER`, `PID_EXTRUDER1`
   - `CALIBRATE_Z_START` → `CALIBRATE_Z_SAVE` → `CALIBRATE_Z_END`
   - `Z_OFFSET.t0` / `t1` — default 8mm on first boot, then overridden by `variables.cfg`.

## ✨ Features

- **Full IDEX support** — `PRIMARY`, `COPY`, `MIRROR` modes with clean carriage decoupling and T0/T1 offset management.
- **IDEX Backup mode** — automatic switch to the backup extruder on filament runout; backup head kept at standby temperature to limit ooze while waiting. Activated by plate name.
- **ADC filament sensor** — emulates the stock Snapmaker firmware logic using the PA4 / PA0 optical encoders, auto-pause on jam or auto-switch to backup extruder in BACKUP mode.
- **PT100 nozzle ADC sensor** — conversion table generated for the Snapmaker voltage divider (`Snapmaker J1 Nozzle`).
- **Filament load/unload** — `LOAD_T0`, `LOAD_T1`, `UNLOAD_T0`, `UNLOAD_T1` macros tuned for the J1s direct drive.

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
│   └── MCU_temp_fan.cfg     # Enclosure fan on PC6 — auto PID control (always active)
│
├── macros/
│   ├── macros.cfg           # Logging + homing flag + G1 override + BLINK_LED + M600
│   ├── idex.cfg             # COPY / MIRROR / PRIMARY / BACKUP + T0/T1 + M104/M109/M106/M107
│   ├── calibration.cfg      # Cross-head Z calibration + nozzle cleaning
│   ├── filament.cfg         # LOAD / UNLOAD T0 / T1
│   ├── purge.cfg            # Purge lines with post-purge nozzle wipe
│   ├── start_end_pause.cfg  # START_PRINT / END_PRINT / PAUSE / RESUME / CANCEL
│   ├── pid.cfg              # PID_BED / PID_EXTRUDER / PID_EXTRUDER1
│   └── test_speed.cfg       # IDEX-safe speed/accel test
│
└── Extras/                  # Optional configs — activate via printer.cfg includes
    ├── MMB_cubic.cfg           # BTT MMB Cubic V1.0 — secondary MCU (RP2040, 3× fans)
    ├── MMB_aux_fan.cfg         # Auxiliary fan on MMB Cubic FAN0 (gpio8)
    ├── adxl345_fysetc_v1.cfg   # FYSETC v1 ADXL345 input shaper (USB RP2040) — included by shaketune.cfg
    ├── shaketune.cfg           # Klippain-ShakeTune + ADXL345 + SHAKETUNE_T0 / SHAKETUNE_T1 macros
    └── shaketune_toggle.cfg    # SHAKETUNE_ENABLE / SHAKETUNE_DISABLE macros (always loaded)
```

Includes in `printer.cfg`:

```ini
[include mainsail.cfg]
[include hardware/*.cfg]             # includes MCU_temp_fan.cfg automatically
[include macros/*.cfg]
[include Extras/shaketune_toggle.cfg]    # ShakeTune toggle macros (always active)
#[include Extras/MMB_cubic.cfg]          # uncomment to enable MMB Cubic secondary MCU
#[include Extras/MMB_aux_fan.cfg]        # uncomment to enable auxiliary fan (requires MMB_cubic.cfg)
#[include Extras/shaketune.cfg]          # uncomment when ADXL345 is connected
```



## 🎛️ Main macros

| Macro | Description |
|---|---|
| `START_PRINT` | Heat, home, purge + nozzle wipe, auto IDEX mode from plate name |
| `END_PRINT` | Anti-ooze (cool to 160°C + 10mm retract), Z hop, park T0 + T1 |
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
| `BLINK_LED [COUNT=3] [ON_MS=200] [OFF_MS=200]` | Blink enclosure LED — end-of-action signal |
| `SHAKETUNE_ENABLE` / `SHAKETUNE_DISABLE` | Enable/disable ShakeTune + ADXL345 (edits printer.cfg + restarts) |
| `SHAKETUNE_T0` / `SHAKETUNE_T1` | Input shaper calibration on T0 or T1 (parks inactive head, runs AXES_SHAPER_CALIBRATION) |


## 🔀 IDEX mode selection from plate name

`START_PRINT` detects the print mode from the `PLATE=` slicer parameter (plate/profile name). The plate name only needs to **contain** the corresponding keyword (case-insensitive):

| Keyword in plate name | IDEX mode |
|---|---|
| *(none)* | PRIMARY — T0 if `T0_TEMP > 0`, T1 if only `T1_TEMP > 0` |
| `copy` | COPY — both heads print the same part side by side |
| `mirror` | MIRROR — both heads print symmetrically about the bed centre |
| `backup` | BACKUP — T0 primary, T1 on standby; auto-switch to T1 on T0 runout |
| `backup_t1` | BACKUP — T1 primary, T0 on standby; auto-switch to T0 on T1 runout |

In BACKUP mode, the standby head is kept at `print_temp − 70 °C` to limit ooze while waiting. On filament runout, the backup head heats back up to print temperature before continuing — no user intervention required. If the backup head also runs out, the print pauses normally.

## 🖨️ OrcaSlicer configuration

See [OrcaSlicer.md](OrcaSlicer.md) for the complete OrcaSlicer setup guide:
- Machine profile (bed dimensions, extruder count)
- Start / End G-Code with correct variable syntax
- IDEX mode selection by plate name
- Filament density table for volumetric flush
- Printer connection (Moonraker)

> 🇫🇷 French version: [OrcaSlicer_FR.md](OrcaSlicer_FR.md)

---

## 🐧 Armbian host optimisations

See [Armbian_Optimisations_EN.md](Armbian_Optimisations_EN.md) for the recommended host tuning applied to the embedded Armbian board:
- **zram swap** (481 MB compressed, no flash wear)
- Disabling unnecessary services (NFS, vnstat, unattended-upgrades)
- journald log size limits
- `noatime` mount option to reduce flash writes
- `vm.swappiness=10` sysctl tuning

> 🇫🇷 French version: [Armbian_Optimisations_FR.md](Armbian_Optimisations_FR.md)

---

## 🗄️ Mainsail UI backup and restore

The `backup-mainsail.json` file contains a complete backup of the Mainsail interface.

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

GPLv3 — see `LICENSE`. Some files (notably `mainsail.cfg`) are redistributed under their original license from [mainsail-crew](https://github.com/mainsail-crew).

## 🙏 Credits

- **[Evil Azrael](https://wiki.evilazrael.de/en/snapmaker-j1-klipper-installation)** — Snapmaker J1/J1s Klipper installation guide and reverse-engineering work. This project would not exist without him.
- [Klipper](https://github.com/Klipper3d/klipper) — Kevin O'Connor & contributors
- [Mainsail](https://github.com/mainsail-crew/mainsail) — mainsail-crew
- The Snapmaker J1/J1s community
