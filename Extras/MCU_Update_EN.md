# MCU Firmware Update — Complete Guide

Guide to updating Klipper firmware on the Snapmaker J1s MCUs from an SSH terminal.

> 🇫🇷 Version française : [MCU_Update_FR.md](MCU_Update_FR.md)

---

## MCUs covered

| MCU | Chip | Interface | Script |
|---|---|---|---|
| J1s main MCU | GD32F307 | `/dev/ttyMSM1` (SACP protocol) | `flash_main_mcu.sh` |
| BTT MMB Cubic V1.0 | RP2040 | USB mass storage (UF2) | `build_mmb_firmware.sh` |

---

## Prerequisites — setup script

Run **once** after the first repo deployment, via SSH:

```bash
bash ~/printer_data/config/Extras/scripts/setup_mcu_update.sh
```

This script:
1. Fixes the Klipper repo "dirty" state (see dedicated section below)
2. Adds a sudoers rule to stop/start Klipper without a password prompt
3. Makes the scripts executable

---

## Updating the J1s main MCU (GD32F307)

Connect via SSH, then:

```bash
bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh
```

**Interactive sequence:**
```
==> Checking prerequisites
[OK]    ~/klipper found
[OK]    Build config: snapmakerj1.config
[OK]    Flash script: scripts/j1_flash_firmware.py
[OK]    Serial port: /dev/ttyMSM1

==> Building Klipper firmware (GD32F307)
...compilation...
[OK]    Firmware built: ~/klipper/out/klipper.bin (128K)

==> Ready to flash
[WARN]  Klipper will be STOPPED for the flash operation.
[WARN]  Mainsail will lose connection until Klipper restarts (~30-60 s).

Proceed? [y/N]        ← confirmation before any shutdown
```

After confirmation:
1. Klipper stops
2. Bootloader trigger sent on `/dev/ttyMSM1`
3. Firmware flashed via SACP protocol
4. Klipper restarts automatically

**Build-only option** (no flash, Klipper stays running):
```bash
bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh --build-only
```

---

## Updating the BTT MMB Cubic (RP2040)

RP2040 flashing uses USB mass storage — Klipper is not stopped.

**Step 1 — Build the firmware:**
```bash
bash ~/printer_data/config/Extras/scripts/build_mmb_firmware.sh
```

The script prints the UF2 file path and the copy command at the end.

**Step 2 — Flash manually:**
1. Hold the **BOOT** button on the MMB Cubic
2. Plug in the USB cable — the module appears as the `RPI-RP2` drive
3. Copy the firmware to the drive:
   ```bash
   cp ~/klipper/out/klipper.uf2 /media/pi/RPI-RP2/
   ```
4. The board reboots automatically

---

## Resolving the "repo is dirty" problem

Moonraker's update manager blocks Klipper updates when the git repo is "dirty". On the J1s this is systematic because the snapmakerj1 fork diverges from standard Klipper in several ways.

### Cause 1 — Files deleted by the snapmakerj1 fork

The fork removes AVR support (replaced by GD32). These deletions appear as uncommitted modifications. Fix:

```bash
cd ~/klipper
git ls-files src/avr/ | xargs git update-index --skip-worktree
```

`--skip-worktree` tells git to permanently ignore these files in status checks without restoring them.

### Cause 2 — Untracked files specific to the fork

The fork adds J1s-specific files (`snapmakerj1.config`, `src/gd32/`, etc.) and extra tools (`gcode_shell_command.py`, `j1_flash_firmware.py`). Fix via `.git/info/exclude`:

```bash
cd ~/klipper
cat >> .git/info/exclude << 'EOF'
.config.main
.config.rp2040
snapmakerj1.config
config/printer-snapmaker-j1-printer.cfg
config/snapmakerj1_defconfig
lib/gd32f3/
src/gd32/
klippy/extras/gcode_shell_command.py
scripts/j1_flash_firmware.py
EOF
```

`.git/info/exclude` is equivalent to a local `.gitignore`: not committed, not shared, survives `git pull`.

### Cause 3 — Manually modified `src/Kconfig`

If `src/Kconfig` was manually edited (e.g. to enable RP2040 during a firmware build), restore it:

```bash
cd ~/klipper
git checkout src/Kconfig
```

> `setup_mcu_update.sh` applies all three fixes automatically.

---

## File layout

```
printer_data/config/
└── Extras/
    ├── MCU_Update_EN.md            # This document
    ├── MCU_Update_FR.md            # French version
    └── scripts/
        ├── setup_mcu_update.sh     # One-time setup — run once via SSH
        ├── flash_main_mcu.sh       # Build + flash J1s main MCU (GD32F307)
        └── build_mmb_firmware.sh   # Build RP2040 firmware for MMB Cubic

~/klipper/
├── snapmakerj1.config              # make config for GD32F307
├── .config.rp2040                  # make config for RP2040 (MMB Cubic)
└── scripts/
    └── j1_flash_firmware.py        # SACP firmware flash tool (Snapmaker protocol)
```

---

## Technical detail: SACP protocol

The J1s main MCU (GD32F307) does not use standard USB DFU. It uses the SACP (Snapmaker Application Communication Protocol, command set `0xAD`) in 3 phases:

1. **Start Update** — send a 256-byte header, validated by the MCU
2. **Chunk Transfer** — firmware transferred in blocks on demand from the MCU
3. **Notify Update Result** — result confirmation

With `--klipper`, `j1_flash_firmware.py` first sends the Klipper bootloader trigger (`~ \x1c Request Serial Bootloader!! ~` at 250000 baud) to switch the MCU into update mode before starting the SACP protocol.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Serial port /dev/ttyMSM1 not found` | Printer off or cable disconnected | Check physical connection |
| `Build failed` | Compilation error | Check `snapmakerj1.config` in `~/klipper/` |
| `Flash failed` | MCU not responding to bootloader | Power-cycle the printer, re-run the script |
| Moonraker shows "repo is dirty" | Modified files in `~/klipper/` | Re-run `setup_mcu_update.sh` |
| `sudo: a password is required` | Sudoers rule missing | Re-run `setup_mcu_update.sh` or enter password manually |
| `RPI-RP2` drive does not appear | BOOT button not held | Replug while holding BOOT **before** connecting USB |
