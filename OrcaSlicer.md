# OrcaSlicer Configuration — Snapmaker J1 / J1s + Klipper

OrcaSlicer setup guide for the Snapmaker J1 / J1s with this Klipper firmware.

> 🇫🇷 Une version française est disponible dans [OrcaSlicer_FR.md](OrcaSlicer_FR.md).

---

## 1. Machine profile

### Bed dimensions

| Parameter | Value |
|---|---|
| Width (X) | 330 mm |
| Depth (Y) | 200 mm |
| Height (Z) | 205 mm |
| Bed exclusion zone | 0x0, 10x0, 10x200, 0x200 |
| Nozzle diameter | 0.4 mm |
| Filament diameter | 1.75 mm |

### Extruder settings

- **Number of extruders**: 2 (IDEX)
- **T0**: left extruder (primary)
- **T1**: right extruder

---

## 2. Start G-Code

Paste into **Machine > Start G-Code**:

```gcode
START_PRINT BED_TEMP={first_layer_bed_temperature[0]} T0_TEMP={nozzle_temperature_initial_layer[0]} T1_TEMP={nozzle_temperature_initial_layer[1]} PLATE={plate_name} SPACING=165 DENSITY_T0={filament_density[0]} DENSITY_T1={filament_density[1]}
```

> **Note**: `PLATE={plate_name}` passes the OrcaSlicer plate name to the `START_PRINT` macro, which uses it to detect the IDEX mode (see section 4).

### `START_PRINT` parameters

| Parameter | Default | Description |
|---|---|---|
| `BED_TEMP` | 60 | Bed temperature (°C) |
| `T0_TEMP` | 0 | Left nozzle T0 temperature (°C) |
| `T1_TEMP` | 0 | Right nozzle T1 temperature (°C) |
| `PLATE` | *(empty)* | Plate name — used for IDEX mode detection |
| `SPACING` | 165 | Head spacing in COPY mode (mm) |
| `DENSITY_T0` | 1.24 | T0 filament density (g/cm³) — for volumetric flush |
| `DENSITY_T1` | 1.24 | T1 filament density (g/cm³) — for volumetric flush |

---

## 3. End G-Code

Paste into **Machine > End G-Code**:

```gcode
END_PRINT
```

---

## 4. IDEX mode selection by plate name

`START_PRINT` automatically detects the IDEX mode from the plate name passed via `PLATE=`. The plate name only needs to **contain** the corresponding keyword (case-insensitive).

| Keyword in plate name | IDEX mode |
|---|---|
| *(none)* | PRIMARY — T0 if `T0_TEMP > 0`, T1 if only `T1_TEMP > 0` |
| `copy` | COPY — both heads print the same part side by side |
| `mirror` | MIRROR — both heads print symmetrically about the bed centre |
| `backup` | BACKUP — T0 primary, T1 on standby; auto-switch to T1 on T0 runout |
| `backup_t1` | BACKUP — T1 primary, T0 on standby; auto-switch to T0 on T1 runout |

### Suggested OrcaSlicer plate names

| Suggested name | Mode |
|---|---|
| `PEI` / `Smooth` / `Textured` | PRIMARY (T0 or T1 depending on temperatures) |
| `PEI copy` | COPY |
| `PEI mirror` | MIRROR |
| `PEI backup` | BACKUP T0 → T1 |
| `PEI backup_t1` | BACKUP T1 → T0 |

> **Tip**: In OrcaSlicer, plates are managed under **Prepare > Print Settings > Plate name**. Create one plate per IDEX mode and name it according to the table above.

---

## 5. Filament profiles — common densities

The `DENSITY_T0` / `DENSITY_T1` parameters are used to calculate the pre-purge flush volume. Setting the correct density improves purge quality during colour or material changes.

| Material | Density (g/cm³) |
|---|---|
| PLA | 1.24 |
| PETG | 1.27 |
| ABS | 1.05 |
| ASA | 1.07 |
| TPU 95A | 1.21 |
| Nylon PA6 | 1.14 |
| PC | 1.20 |

In OrcaSlicer, set the density under **Filament > Advanced > Density**.

---

## 6. Dual-material printing (T0 + T1) — PRIMARY

To print with both T0 and T1 in standard PRIMARY mode:

1. Assign objects to T0 (`Extruder 1`) and T1 (`Extruder 2`) in OrcaSlicer.
2. Set `T0_TEMP` **and** `T1_TEMP` in the respective filament profiles.
3. Name the plate without any IDEX keyword (e.g. `PEI`).
4. `START_PRINT` heats both heads and activates T0 first.

---

## 7. COPY mode

Both heads print **the same part** simultaneously, side by side. T1 mirrors T0 movements with an X offset.

- **Default spacing**: 165 mm (`SPACING` parameter).
- To override: add `SPACING=xxx` to the Start G-Code.
- Design the part in the **left half** of the bed (≤ 175 mm in X).
- Use an **identical** filament profile on T0 and T1, or set `T1_TEMP` to 0 (the macro will automatically use `T0_TEMP` for T1).

---

## 8. MIRROR mode

Both heads print **mirrored** about the bed centre.

- The part is **mirrored automatically** — import only one part.
- Design within the **left half** of the bed.
- Same temperature rules as COPY mode.

---

## 9. BACKUP mode

The standby head is kept at `print_temp − 70 °C` during the print. When the ADC filament sensor detects a runout, it automatically heats back up to print temperature and resumes — no user intervention required.

- Assign **the entire object to T0** (or T1 depending on the chosen backup mode) in OrcaSlicer.
- If both heads run out of filament, the print pauses normally.

---

## 10. General tips

- **Retraction**: with the J1s direct drive, use 0.5–1.0 mm at 30–50 mm/s.
- **Travel speed**: max 350 mm/s, max acceleration 3000 mm/s².
- **Z offset**: set via `CALIBRATE_Z_START` / `CALIBRATE_Z_SAVE` / `CALIBRATE_Z_END`, persisted automatically — do not adjust manually in OrcaSlicer.
- **Safe distance**: both heads must maintain a minimum gap of 21 mm.

---

## 11. Connecting to the printer

In **OrcaSlicer > Preferences > Printer**:

- **Connection type**: Moonraker / Klipper
- **IP address**: your Raspberry Pi address (e.g. `http://192.168.x.x`)
- **Port**: 80 (default Mainsail / Moonraker)
