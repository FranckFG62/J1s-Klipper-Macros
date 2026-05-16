# J1s-Klipper-Macros

Configuration Klipper complète pour la **Snapmaker J1 / J1s** (imprimante 3D IDEX), incluant macros IDEX (PRIMARY / COPY / MIRROR / BACKUP), calibration Z, gestion filament via capteurs ADC.

> ⚠️ **Prérequis** — Cette configuration suppose que Klipper est **déjà installé** sur votre Snapmaker J1/J1s. Suivez impérativement le guide d'installation d'**Evil Azrael** avant d'utiliser ce repo :
> 👉 **https://wiki.evilazrael.de/en/snapmaker-j1-klipper-installation**
>
> Un grand merci à **Evil Azrael** pour son travail remarquable de reverse-engineering et de documentation, sans lequel rien de tout ceci ne serait possible. 🙏

> 🇬🇧 An English version of this documentation is available in [README.md](README.md).

---
## 🚀 Installation

1. **Cloner dans `~/printer_data/config/`** :
   ```bash
   cd ~/printer_data/config
   git clone https://github.com/FranckFG62/J1s-Klipper-Macros.git .
   ```
   ⚠️ Faites une sauvegarde de votre configuration existante avant toute manipulation.

2. **Adapter les offsets dans `printer.cfg`** :
   - `_J1_CONFIG.right_nozzle_adjust_x` / `_y` — offset mécanique XY entre T0 et T1.

     L'étalonnage automatique du décalage XY n'est pas implémenté,cette étape est donc manuelle.

     Utilisez le modèle du package téléchargé. Il s'agit d'une version déjà intégrée de l'étalonnage XY par «LMaker» disponible à l'adresse https://www.printables.com/model/129617-offset-xy-dual-extruder-idex-calibration. Vous y trouverez également des explications sur l'interprétation des résultats.

      En résumé:

      Imprimez la partie inférieure du modèle avec l'extrudeur gauche et la partie supérieure avec l'extrudeur droit.
      Sur le modèle imprimé, vous verrez deux axes avec des barres.

      Sur chaque axe, repérez la barre parfaitement alignée, du côté positif ou négatif. Multipliez l'indice (à partir de 0) de la barre correspondante par 0,1 pour obtenir le décalage. Par exemple, si la troisième barre négative correspond, le calcul est: (3 - 1) * -0,1 = -0,2.

      Modifiez le fichier printer.cfg. Vous pouvez le faire via l'interface web. Trouvez les lignes `variable_right_nozzle_adjust_x: 0` et `variable_right_nozzle_adjust_y: 0`.
      Soustrayez le décalage calculé de la valeur actuelle.

      Enregistrez, redémarrez Klipper, imprimez à nouveau. les premières barres de chaque axe devraient être alignées.


3. **Calibration initiale** — dans cet ordre :
   - `PID_BED`, `PID_EXTRUDER`, `PID_EXTRUDER1`
   - `CALIBRATE_Z_START` → `CALIBRATE_Z_SAVE` → `CALIBRATE_Z_END`
    - `Z_OFFSET.t0` / `t1` — valeurs par défaut 8mm au premier boot, remplacées ensuite par `variables.cfg`.

## ✨ Fonctionnalités

- **IDEX complet** — modes `PRIMARY`, `COPY`, `MIRROR` avec découplage propre des chariots et gestion des offsets T0/T1.
- **Mode IDEX Backup** — bascule automatique sur la tête de secours en cas de fin/blocage de filament ; la tête backup est maintenue en température veille pour limiter le suintement. Activé par le nom du plateau slicer.
- **Capteur filament ADC** — émulation de la logique firmware Snapmaker stock via les encodeurs optiques PA4 / PA0, avec pause automatique en cas de blocage ou bascule automatique sur la tête backup en mode BACKUP.
- **Capteur ADC buse PT100** — table de conversion générée pour le pont diviseur Snapmaker (`Snapmaker J1 Nozzle`).
- **Chargement / déchargement filament** — macros `LOAD_T0`, `LOAD_T1`, `UNLOAD_T0`, `UNLOAD_T1` calibrées pour le direct drive J1s.

## 📁 Arborescence

```
printer_data/
├── printer.cfg              # Point d'entrée — includes + PID + Z offsets
├── mainsail.cfg             # Macros client Mainsail (pause/resume/cancel)
├── moonraker.conf           # Configuration Moonraker
├── sonar.conf               # WiFi keepalive
├── variables.cfg            # Persistance des Z offsets (auto-généré)
├── backup-mainsail.json     # Sauvegarde UI Mainsail
│
├── hardware/
│   ├── hardware.cfg         # MCU, steppers, extruders, heaters, fans
│   ├── adc_nozzle_temp.cfg  # Table ADC PT100 buse Snapmaker
│   ├── filament_sensor.cfg  # Capteur filament via ADC (PA4 / PA0)
│   └── MCU_temp_fan.cfg     # Fan caisson sur PC6 — contrôle PID automatique (toujours actif)
│
├── macros/
│   ├── macros.cfg           # Logging + flag homing + surcharge G1 + BLINK_LED + M600
│   ├── idex.cfg             # COPY / MIRROR / PRIMARY / BACKUP + T0/T1 + M104/M109/M106/M107
│   ├── calibration.cfg      # Calibration Z inter-têtes + nettoyage buses
│   ├── filament.cfg         # LOAD / UNLOAD T0 / T1
│   ├── purge.cfg            # Lignes de purge avec essuyage buse en fin de purge
│   ├── start_end_pause.cfg  # START_PRINT / END_PRINT / PAUSE / RESUME / CANCEL
│   ├── pid.cfg              # PID_BED / PID_EXTRUDER / PID_EXTRUDER1
│   └── test_speed.cfg       # Test vitesse / accélération sécurisé IDEX
│
└── Extras/                  # Configs optionnelles — activées via les includes de printer.cfg
    ├── MMB_cubic.cfg           # BTT MMB Cubic V1.0 — MCU secondaire (RP2040, 3× fans)
    ├── MMB_aux_fan.cfg         # Fan auxiliaire sur MMB Cubic FAN0 (gpio8)
    ├── adxl345_fysetc_v1.cfg   # FYSETC v1 ADXL345 hardware (RP2040 USB) — inclus par ADXL.cfg
    ├── ADXL.cfg                # Macros input shaper : SHAPER_CALIBRATE_T0 / T1, sauvegarde auto dans variables.cfg
    ├── ADXL_toggle.cfg         # Macros ADXL_ENABLE / ADXL_DISABLE + init_shaper au boot (toujours chargé)
    └── INPUT_SHAPER.md         # ← Guide d'installation et workflow de calibration
```

Les includes dans `printer.cfg` :

```ini
[include mainsail.cfg]
[include hardware/*.cfg]           # inclut MCU_temp_fan.cfg automatiquement
[include macros/*.cfg]
[include Extras/ADXL_toggle.cfg]   # init input shaper au boot + macros toggle (toujours actif)
#[include Extras/MMB_cubic.cfg]    # décommenter pour activer le MCU secondaire MMB Cubic
#[include Extras/MMB_aux_fan.cfg]  # décommenter pour le fan auxiliaire (nécessite MMB_cubic.cfg)
[include Extras/ADXL.cfg]         # activé/désactivé par ADXL_ENABLE / ADXL_DISABLE — commenter si ADXL non branché
```



## 🎛️ Macros principales

| Macro | Description |
|---|---|
| `START_PRINT` | Chauffe, homing, purge + essuyage buse, sélection auto du mode IDEX selon le nom du plateau |
| `END_PRINT` | Anti-suintement (refroidissement 160°C + rétractation 10mm), dégagement Z, parking T0 + T1 |
| `PAUSE` / `RESUME` | Sauvegarde/restauration complète (position, mode IDEX, températures, fans) |
| `IDEX_COPY [SPACING=165]` | Active le mode COPY |
| `IDEX_MIRROR` | Active le mode MIRROR |
| `IDEX_PRIMARY` | Retour impression normale T0 |
| `IDEX_BACKUP [BACKUP=0\|1]` | Active le mode BACKUP — bascule automatique sur la tête de secours en cas de fin de filament |
| `T0` / `T1` | Switch d'extrudeur avec parking source automatique |
| `LOAD_T0` / `LOAD_T1` | Chargement filament 60mm + purge 30mm |
| `UNLOAD_T0` / `UNLOAD_T1` | Déchargement 80mm avec pré-purge |
| `NOZZLE_CLEAN` / `NOZZLE_CLEAN_END` | Nettoyage manuel des buses |
| `CALIBRATE_Z_START/SAVE/END` | Procédure calibration Z inter-têtes |
| `TEST_SPEED CARRIAGE=0\|1` | Test vitesse sécurisé par chariot |
| `BLINK_LED [COUNT=3] [ON_MS=200] [OFF_MS=200]` | Clignotement LED caisson — signal de fin d'action |
| `ADXL_ENABLE` / `ADXL_DISABLE` | Active/désactive l'ADXL345 (modifie printer.cfg + redémarre Klipper) |
| `SHAPER_CALIBRATE_T0` | Calibration input shaper T0 — mesure X+Y, sauvegarde automatique dans `variables.cfg` |
| `SHAPER_CALIBRATE_T1` | Calibration input shaper T1 — mesure X uniquement (Y partagé avec T0), sauvegarde auto |
| `SAVE_SHAPER_PARAMS CARRIAGE=0\|1 ...` | Persistance manuelle des valeurs shaper — voir [INPUT_SHAPER.md](Extras/INPUT_SHAPER.md) |


## 🔀 Sélection du mode IDEX par nom de plateau

`START_PRINT` détecte le mode d'impression à partir du paramètre `PLATE=` du slicer (nom du plateau/profil). Nommez votre plateau slicer avec l'un des mots-clés suivants :

| Mot-clé dans le nom du plateau | Mode |
|---|---|
| *(aucun)* | PRIMARY — T0 si `T0_TEMP > 0`, T1 si seulement `T1_TEMP > 0` |
| `copy` | COPY — les deux têtes impriment la même pièce côte à côte |
| `mirror` | MIRROR — les deux têtes impriment en symétrie par rapport au centre du plateau |
| `backup` | BACKUP — T0 primaire, T1 en veille ; bascule auto sur T1 en cas de fin de filament T0 |
| `backup_t1` | BACKUP — T1 primaire, T0 en veille ; bascule auto sur T0 en cas de fin de filament T1 |

En mode BACKUP, la tête en veille est maintenue à `temp_impression − 70 °C` pour limiter le suintement. En cas de fin de filament, elle remonte automatiquement à la température d'impression avant de reprendre — aucune intervention utilisateur nécessaire. Si la tête backup manque aussi de filament, l'impression se met en pause normalement.

## 🖨️ Configuration OrcaSlicer

Voir [OrcaSlicer_FR.md](OrcaSlicer_FR.md) pour le guide complet de configuration OrcaSlicer :
- Profil machine (dimensions plateau, nombre d'extrudeurs)
- Start / End G-Code avec la syntaxe de variables correcte
- Sélection du mode IDEX par nom de plateau
- Table de densités filament pour le flush volumétrique
- Connexion à l'imprimante (Moonraker)

> 🇬🇧 English version: [OrcaSlicer.md](OrcaSlicer.md)

---

## 🐧 Optimisations host Armbian

Voir [Armbian_Optimisations_FR.md](Armbian_Optimisations_FR.md) pour les réglages recommandés sur la carte Armbian embarquée :
- **zram swap** (481 MB compressé, sans usure de la flash)
- Désactivation des services inutiles (NFS, vnstat, unattended-upgrades)
- Limites de taille des logs journald
- Option de montage `noatime` pour réduire les écritures flash
- Réglage sysctl `vm.swappiness=10`

> 🇬🇧 English version: [Armbian_Optimisations_EN.md](Armbian_Optimisations_EN.md)

---

## 🗄️ Sauvegarde et restauration de l'interface Mainsail

Le fichier `backup-mainsail.json` contient une sauvegarde complète de l'interface Mainsail :

### Procédure de restauration

1. Téléchargez le fichier `backup-mainsail.json` depuis ce dépôt.
2. Ouvrez l'interface Mainsail dans votre navigateur.
3. Cliquez sur l'icône **Paramètres** (⚙️) en haut à droite.
4. Dans le menu de gauche, allez dans **"Généraux"** puis faites défiler jusqu'à la section **Sauvegarde**.
5. Cliquez sur **"Restaurer"**, sélectionnez le fichier `backup-mainsail.json` et confirmez.

> ℹ️ Cette opération ne modifie que l'interface (UI) Mainsail, pas la configuration Klipper.

## ⚠️ Avertissements

> Ces fichiers sont fournis **sans garantie**. Une mauvaise configuration peut endommager votre imprimante. Vérifiez pin assignments, courants moteurs et offsets avant tout mouvement. L'auteur décline toute responsabilité en cas de dommage.

---

## 📜 Licence

GPLv3 — voir `LICENSE`. Certains fichiers (notamment `mainsail.cfg`) sont redistribués sous leur licence d'origine depuis [mainsail-crew](https://github.com/mainsail-crew).

## 🙏 Remerciements

- **[Evil Azrael](https://wiki.evilazrael.de/en/snapmaker-j1-klipper-installation)** — Guide d'installation Klipper pour la J1/J1s et travail de reverse-engineering. Ce projet n'existerait pas sans lui.
- [Klipper](https://github.com/Klipper3d/klipper) — Kevin O'Connor & contributeurs
- [Mainsail](https://github.com/mainsail-crew/mainsail) — mainsail-crew
- La communauté Snapmaker J1/J1s
