# Input Shaper — J1s IDEX

Guide d'installation et d'utilisation de l'input shaper sur le Snapmaker J1/J1s.

---

## Matériel requis

**FYSETC Portable Input Shaper v1** — module ADXL345 USB (RP2040).  
Serial : `usb-Klipper_rp2040_E66160F4236A8F37-if00`

---

## Installation logicielle (une seule fois, via SSH)

### 1. Paquets système

```bash
sudo apt install python3-numpy python3-matplotlib libopenblas-dev
```

### 2. Dépendances Python dans le venv Klipper

La version de numpy fournie par pip est trop ancienne pour Python 3.13+. Il faut forcer une version récente :

```bash
source ~/klippy-env/bin/activate
pip install --upgrade pip setuptools wheel
pip install "numpy>=2.0"
deactivate
```

### 3. Extension `gcode_shell_command`

Requise pour les macros `ADXL_ENABLE` / `ADXL_DISABLE`.  
Installer via **KIAUH → Extensions → gcode_shell_command**.

### 4. Rendre les scripts exécutables

```bash
chmod +x ~/printer_data/config/Extras/scripts/ADXL_enable.sh
chmod +x ~/printer_data/config/Extras/scripts/ADXL_disable.sh
```

---

## Spécificités J1s IDEX

> La section `[input_shaper]` est **interdite** par Klipper quand `dual_carriage` est actif.

Les valeurs sont appliquées au démarrage via un `[delayed_gcode init_shaper]` qui lit `variables.cfg`, et **ne nécessitent pas de `SAVE_CONFIG`**.

Chaque chariot a son propre profil X. L'axe Y est partagé (calibré sur T0 uniquement).

---

## Utilisation

### Activer l'ADXL

1. Brancher le module FYSETC sur un port USB de la J1s.
2. Depuis la console Mainsail : `ADXL_ENABLE`  
   → Klipper redémarre automatiquement avec le module actif.

### Désactiver l'ADXL

Depuis la console Mainsail : `ADXL_DISABLE`  
→ Klipper redémarre sans le module (débrancher l'USB après).

---

## Calibration

### T0 (chariot gauche)

1. Fixer l'ADXL345 sur la tête T0.
2. Console Mainsail :
```
SHAPER_CALIBRATE_T0
```
→ Le chariot se home, T1 se gare à droite, la mesure démarre.  
→ Les valeurs X et Y sont **sauvegardées automatiquement** dans `variables.cfg`.

### T1 (chariot droit)

1. Déplacer l'ADXL345 sur la tête T1.
2. Console Mainsail :
```
SHAPER_CALIBRATE_T1
```
→ Mesure X uniquement (Y identique à T0 — axe partagé).  
→ La valeur X est **sauvegardée automatiquement** dans `variables.cfg`.

### Appliquer les valeurs

```
FIRMWARE_RESTART
```

Le `[delayed_gcode init_shaper]` recharge les valeurs 0,1 s après le démarrage et les applique à chaque chariot.

---

## Correction manuelle

Si besoin de corriger une valeur sans recalibrer :

```
SAVE_SHAPER_PARAMS CARRIAGE=0 SHAPER_TYPE_X=mzv SHAPER_FREQ_X=48.6 SHAPER_TYPE_Y=2hump_ei SHAPER_FREQ_Y=70.2
SAVE_SHAPER_PARAMS CARRIAGE=1 SHAPER_TYPE_X=mzv SHAPER_FREQ_X=52.0
```

Puis `FIRMWARE_RESTART`.
