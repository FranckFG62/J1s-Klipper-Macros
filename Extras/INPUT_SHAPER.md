# Input Shaper — J1s IDEX

Installation and calibration guide for input shaper on the Snapmaker J1/J1s.

---

## Required hardware

**FYSETC Portable Input Shaper v1** — ADXL345 USB module (RP2040).  
Serial: `usb-Klipper_rp2040_E66160F4236A8F37-if00`

Support: https://www.printables.com/model/1723184-adxl-fystec-pis-mount-for-snampmaker-j1
---

## Software installation (once, via SSH)

### 1. System packages

```bash
sudo apt install python3-numpy python3-matplotlib libopenblas-dev
```

> `libatlas-base-dev` is **not available** on recent distributions — `libopenblas-dev` replaces it.

### 2. Python dependencies in the Klipper venv

The numpy version provided by pip is too old for Python 3.13+. Force a recent version:

```bash
source ~/klippy-env/bin/activate
pip install --upgrade pip setuptools wheel
pip install "numpy>=2.0"
deactivate
```

### 3. `gcode_shell_command` extension

Required for the `ADXL_ENABLE` / `ADXL_DISABLE` macros.  
Install via **KIAUH → Extensions → gcode_shell_command**.

### 4. Make scripts executable

```bash
chmod +x ~/printer_data/config/Extras/scripts/ADXL_enable.sh
chmod +x ~/printer_data/config/Extras/scripts/ADXL_disable.sh
```

---

## J1s IDEX specifics

> The `[input_shaper]` section is **forbidden** by Klipper when `dual_carriage` is active.

Values are applied at boot via a `[delayed_gcode init_shaper]` that reads `variables.cfg` — **no `SAVE_CONFIG` needed**.

Each carriage has its own X profile. The Y axis is shared (calibrated on T0 only).

---

## Usage

### Enable the ADXL

1. Plug the FYSETC module into a USB port on the J1s.
2. From the Mainsail console: `ADXL_ENABLE`  
   → Klipper restarts automatically with the module active.

### Disable the ADXL

From the Mainsail console: `ADXL_DISABLE`  
→ Klipper restarts without the module (unplug the USB afterwards).

---

## Calibration

### T0 (left carriage)

1. Mount the ADXL345 on the T0 head.
2. Mainsail console:
```
SHAPER_CALIBRATE_T0
```
→ Carriage homes, T1 parks to the right, measurement starts.  
→ X and Y values are **saved automatically** to `variables.cfg`.

### T1 (right carriage)

1. Move the ADXL345 to the T1 head.
2. Mainsail console:
```
SHAPER_CALIBRATE_T1
```
→ X axis only (Y is identical to T0 — shared axis).  
→ X value is **saved automatically** to `variables.cfg`.

### Apply the values

```
FIRMWARE_RESTART
```

The `[delayed_gcode init_shaper]` reloads the values 0.1 s after boot and applies them to each carriage.

---

## Manual override

To correct a value without recalibrating:

```
SAVE_SHAPER_PARAMS CARRIAGE=0 SHAPER_TYPE_X=mzv SHAPER_FREQ_X=48.6 SHAPER_TYPE_Y=2hump_ei SHAPER_FREQ_Y=70.2
SAVE_SHAPER_PARAMS CARRIAGE=1 SHAPER_TYPE_X=mzv SHAPER_FREQ_X=52.0
```

Then `FIRMWARE_RESTART`.
