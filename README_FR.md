# J1s-Klipper-Macros

Configuration Klipper complète pour la **Snapmaker J1 / J1s** (imprimante 3D IDEX), incluant macros IDEX (PRIMARY / COPY / MIRROR / BACKUP), calibration Z inter-têtes, gestion filament via capteurs ADC, purge adaptative avec essuyage buse et surcharges PAUSE / RESUME / START / END.

> ⚠️ **Prérequis** — Cette configuration suppose que Klipper est **déjà installé** sur votre Snapmaker J1/J1s. Suivez impérativement le guide d'installation d'**Evil Azrael** avant d'utiliser ce repo :
> 👉 **https://wiki.evilazrael.de/en/snapmaker-j1-klipper-installation**
>
> Un grand merci à **Evil Azrael** pour son travail remarquable de reverse-engineering et de documentation, sans lequel rien de tout ceci ne serait possible. 🙏

> 🇬🇧 An English version of this documentation is available in [README.md](README.md).

---

## ✨ Fonctionnalités

- **IDEX complet** — modes `PRIMARY`, `COPY`, `MIRROR` avec découplage propre des chariots et gestion des offsets T0/T1.
- **Mode IDEX Backup** — bascule automatique sur la tête de secours en cas de fin/blocage de filament ; la tête backup est maintenue en température veille pour limiter le suintement. Activé par le nom du plateau slicer.
- **Calibration Z inter-têtes** — procédure guidée en 3 étapes (`CALIBRATE_Z_START` / `SAVE` / `END`) avec persistance via `save_variables`.
- **Capteur filament ADC** — émulation de la logique firmware Snapmaker stock via les encodeurs optiques PA4 / PA0, avec pause automatique en cas de blocage ou bascule automatique sur la tête backup en mode BACKUP.
- **Capteur ADC buse PT100** — table de conversion générée pour le pont diviseur Snapmaker (`Snapmaker J1 Nozzle`).
- **Purge adaptative avec essuyage buse** — flush volumétrique haute température puis ligne de purge (mono-tête ou MIRROR synchronisé), suivi d'un essuyage sur le pad silicone avant le parking.
- **PAUSE / RESUME robustes** — sauvegarde complète de l'état (position, mode IDEX, températures, fans) et restauration fidèle.
- **Chargement / déchargement filament** — macros `LOAD_T0`, `LOAD_T1`, `UNLOAD_T0`, `UNLOAD_T1` calibrées pour le direct drive J1s.
- **Contrôle fan MCU** — refroidissement progressif du boîtier électronique via `temperature_fan`.
- **Surcharge `G1`** — blocage des mouvements Z avant homing pour éviter les collisions dues aux G1 Z injectés par le slicer.

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
│   └── MCU_temp_fan.cfg     # Fan boîtier électronique
│
└── macros/
    ├── macros.cfg           # Logging + flag homing + surcharge G1
    ├── idex.cfg             # COPY / MIRROR / PRIMARY / BACKUP + T0/T1 + M104/M109/M106/M107
    ├── calibration.cfg      # Calibration Z inter-têtes + nettoyage buses
    ├── filament.cfg         # LOAD / UNLOAD T0 / T1
    ├── purge.cfg            # Lignes de purge avec essuyage buse en fin de purge
    ├── start_end_pause.cfg  # START_PRINT / END_PRINT / PAUSE / RESUME / CANCEL
    ├── pid.cfg              # PID_BED / PID_EXTRUDER / PID_EXTRUDER1
    └── test_speed.cfg       # Test vitesse / accélération sécurisé IDEX
```

Les includes dans `printer.cfg` utilisent des wildcards :

```ini
[include mainsail.cfg]
[include hardware/*.cfg]
[include macros/*.cfg]
```

## 🚀 Installation

1. **Cloner dans `~/printer_data/config/`** :
   ```bash
   cd ~/printer_data/config
   git clone https://github.com/<votre-user>/J1s-Klipper-Macros.git .
   ```
   ⚠️ Faites une sauvegarde de votre configuration existante avant toute manipulation.

2. **Adapter `hardware/hardware.cfg`** — vérifier le port MCU (`serial:`), les pins et les courants TMC si votre carte diffère.

3. **Adapter les offsets dans `printer.cfg`** :
   - `_J1_CONFIG.right_nozzle_adjust_x` / `_y` — offset mécanique XY entre T0 et T1.
   - `Z_OFFSET.t0` / `t1` — valeurs par défaut au premier boot, remplacées ensuite par `variables.cfg`.

4. **Redémarrer Klipper** puis lancer `G28` pour vérifier le homing.

5. **Calibration initiale** — dans cet ordre :
   - `PID_BED`, `PID_EXTRUDER`, `PID_EXTRUDER1`
   - `CALIBRATE_Z_START` → `CALIBRATE_Z_SAVE` → `CALIBRATE_Z_END`

## 🎛️ Macros principales

| Macro | Description |
|---|---|
| `START_PRINT` | Chauffe, homing, purge + essuyage buse, sélection auto du mode IDEX selon le nom du plateau |
| `END_PRINT` | Rétract, dégagement Z, parking T0 + T1 |
| `PAUSE` / `RESUME` | Sauvegarde/restauration complète (position, mode IDEX, temps, fans) |
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
| `FILAMENT_STATUS` | Affiche l'état des capteurs ADC |
| `M412 S0\|1` | Active/désactive le capteur filament |

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

## ⚙️ Paramètres notables

- **`_J1_CONFIG`** (dans `printer.cfg`) : offsets mécaniques T1 (`right_nozzle_adjust_x/y`) et flag `wipe_on_activate`.
- **`Z_OFFSET.t0` / `.t1`** : rechargés automatiquement depuis `variables.cfg` 1 s après le boot via `[delayed_gcode _LOAD_Z_OFFSETS]`.
- **`_FILAMENT_VARS`** : seuil ADC (`threshold=15`), erreurs max consécutives (`max_errors=3`), distance de check (`check_distance=2.0` mm).
- **`_J1_RUNTIME_STATE`** : températures et fans mémorisés pour les switchs T0/T1 transparents.

## 🗄️ Sauvegarde et restauration de l'interface Mainsail

Le fichier `backup-mainsail.json` contient une sauvegarde complète de l'interface Mainsail :

- Langue et nom de l'imprimante (`Snapmaker J1`, `fr`)
- Thème et couleurs (`mainsail`, accent `#D41216`)
- **Groupes de macros** : Calibration, IDEX, Print, Filament, ADC — avec visibilité par état (veille / pause / impression)
- **Présets de température** : PLA Extrudeur G, PLA Extrudeur D, PLA IDEX, Préchauffage
- Layout du dashboard (3 colonnes écran large)
- Paramètres de la console et du visualiseur GCode

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
- La communauté Snapmaker pour le reverse-engineering du hardware J1/J1s
