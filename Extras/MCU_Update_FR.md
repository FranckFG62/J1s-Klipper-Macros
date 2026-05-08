# Mise à jour firmware MCU — Guide complet

Guide pour mettre à jour le firmware Klipper des MCU de la Snapmaker J1s depuis un terminal SSH.

> 🇬🇧 English version: [MCU_Update_EN.md](MCU_Update_EN.md)

---

## MCU concernés

| MCU | Puce | Interface | Script |
|---|---|---|---|
| MCU principal J1s | GD32F307 | `/dev/ttyMSM1` (protocole SACP) | `flash_main_mcu.sh` |
| BTT MMB Cubic V1.0 | RP2040 | USB mass storage (UF2) | `build_mmb_firmware.sh` |

---

## Prérequis — script de setup

Exécuter **une seule fois** après le premier déploiement du repo, via SSH :

```bash
bash ~/printer_data/config/Extras/scripts/setup_mcu_update.sh
```

Ce script :
1. Nettoie l'état "dirty" du repo Klipper (voir section dédiée ci-dessous)
2. Ajoute une règle sudoers pour arrêter/démarrer Klipper sans mot de passe
3. Rend les scripts exécutables

---

## Mise à jour du MCU principal J1s (GD32F307)

Connexion SSH à la J1s, puis :

```bash
bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh
```

**Séquence interactive :**
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

Proceed? [y/N]        ← confirmation avant tout arrêt
```

Après confirmation :
1. Klipper s'arrête
2. Trigger bootloader envoyé sur `/dev/ttyMSM1`
3. Firmware flashé via protocole SACP
4. Klipper redémarre automatiquement

**Option build uniquement** (sans flash, Klipper reste actif) :
```bash
bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh --build-only
```

---

## Mise à jour du BTT MMB Cubic (RP2040)

Le flash RP2040 se fait via USB mass storage — Klipper n'est pas arrêté.

**Étape 1 — Compiler le firmware :**
```bash
bash ~/printer_data/config/Extras/scripts/build_mmb_firmware.sh
```

Le script affiche à la fin le chemin du fichier UF2 et la commande de copie.

**Étape 2 — Flasher manuellement :**
1. Maintenir le bouton **BOOT** du MMB Cubic enfoncé
2. Brancher le câble USB — le module apparaît comme le lecteur `RPI-RP2`
3. Copier le firmware sur le lecteur :
   ```bash
   cp ~/klipper/out/klipper.uf2 /media/pi/RPI-RP2/
   ```
4. Le module redémarre automatiquement

---

## Résolution du problème "repo is dirty"

Le gestionnaire de mises à jour Moonraker bloque les mises à jour Klipper si le repo git est "dirty". Ce problème est systématique sur la J1s car le fork snapmakerj1 diverge du Klipper standard de plusieurs façons.

### Cause 1 — Fichiers supprimés du fork snapmakerj1

Le fork retire le support AVR (remplacé par GD32). Ces suppressions apparaissent comme des modifications non commitées. Correction :

```bash
cd ~/klipper
git ls-files src/avr/ | xargs git update-index --skip-worktree
```

`--skip-worktree` indique à git d'ignorer ces fichiers dans les vérifications d'état, de façon permanente et sans les restaurer.

### Cause 2 — Fichiers non suivis propres au fork

Le fork ajoute des fichiers spécifiques (`snapmakerj1.config`, `src/gd32/`, etc.) et des outils supplémentaires (`gcode_shell_command.py`, `j1_flash_firmware.py`). Correction via `.git/info/exclude` :

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

`.git/info/exclude` est l'équivalent d'un `.gitignore` local : non commité, non partagé, survit aux `git pull`.

### Cause 3 — `src/Kconfig` modifié

Si `src/Kconfig` a été modifié manuellement (pour activer RP2040 lors d'une compilation), le restaurer :

```bash
cd ~/klipper
git checkout src/Kconfig
```

> Le script `setup_mcu_update.sh` applique ces trois corrections automatiquement.

---

## Architecture des fichiers

```
printer_data/config/
└── Extras/
    ├── MCU_Update_FR.md            # Ce document
    ├── MCU_Update_EN.md            # Version anglaise
    └── scripts/
        ├── setup_mcu_update.sh     # Setup initial — exécuter 1 fois via SSH
        ├── flash_main_mcu.sh       # Build + flash MCU principal GD32F307
        └── build_mmb_firmware.sh   # Build firmware RP2040 pour MMB Cubic

~/klipper/
├── snapmakerj1.config              # Config make pour GD32F307
├── .config.rp2040                  # Config make pour RP2040 (MMB Cubic)
└── scripts/
    └── j1_flash_firmware.py        # Outil SACP de flash (protocole Snapmaker)
```

---

## Détail technique : protocole SACP

Le MCU principal de la J1s (GD32F307) n'utilise pas le DFU USB standard. Il utilise le protocole SACP (Snapmaker Application Communication Protocol, jeu de commandes `0xAD`) en 3 phases :

1. **Start Update** — envoi d'un header 256 octets, validé par le MCU
2. **Chunk Transfer** — firmware transféré par blocs à la demande du MCU
3. **Notify Update Result** — confirmation du résultat

Avec `--klipper`, `j1_flash_firmware.py` envoie d'abord le message de trigger bootloader Klipper (`~ \x1c Request Serial Bootloader!! ~` à 250000 baud) pour faire passer le MCU en mode mise à jour, puis démarre le protocole SACP.

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Serial port /dev/ttyMSM1 not found` | Imprimante éteinte ou câble débranché | Vérifier la connexion physique |
| `Build failed` | Erreur de compilation | Vérifier `snapmakerj1.config` dans `~/klipper/` |
| `Flash failed` | MCU ne répond pas au bootloader | Power-cycle de l'imprimante, relancer le script |
| Moonraker affiche "repo is dirty" | Fichiers modifiés dans `~/klipper/` | Relancer `setup_mcu_update.sh` |
| `sudo: a password is required` | Règle sudoers manquante | Relancer `setup_mcu_update.sh` ou entrer le mot de passe manuellement |
| Lecteur `RPI-RP2` n'apparaît pas | Bouton BOOT pas maintenu | Rebrancher en maintenant BOOT enfoncé **avant** le branchement USB |
