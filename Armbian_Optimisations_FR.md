# Optimisations Armbian — Snapmaker J1 / J1s

Optimisations appliquées sur le host Armbian embarqué de la J1s (Qualcomm MSM8909, 962 MB RAM).

> 🖥️ **Système** : Armbian 26.2.1 Trixie (Debian 13) — kernel `6.12.1-snapmakerj1-msm8909`

> 🇬🇧 An English version is available in [Armbian_Optimisations_EN.md](Armbian_Optimisations_EN.md).

---

## 1. Swap zram

**Problème** : aucun swap configuré. Sur 962 MB de RAM, un pic simultané Klipper + Moonraker + KlipperScreen peut provoquer un OOM kill.

**Solution** : zram-swap (swap compressé en RAM via zstd — plus rapide et moins usant que du swap sur flash).

```bash
sudo apt-get install -y zram-tools
sudo bash -c 'printf "ALGO=zstd\nPERCENT=50\n" > /etc/default/zramswap'
sudo systemctl enable --now zramswap
```

**Résultat** : 481 MB de swap disponible sans toucher à la flash.

---

## 2. Désactivation des services inutiles

**Problème** : plusieurs services actifs inutiles sur une imprimante 3D — consommation mémoire, ports réseau ouverts, risque de mise à jour automatique cassant Klipper.

| Service | Raison de désactivation |
|---|---|
| `nfs-blkmap` | Service NFS inutile sur imprimante 3D |
| `rpcbind` | Portmapper NFS, inutile |
| `vnstat` | Moniteur réseau, non nécessaire |
| `unattended-upgrades` | Mises à jour auto — risque de casser Klipper / le kernel custom |

```bash
sudo systemctl stop nfs-blkmap rpcbind vnstat unattended-upgrades
sudo systemctl disable nfs-blkmap rpcbind vnstat unattended-upgrades
```

> ⚠️ Les mises à jour système restent possibles manuellement via `sudo apt-get update && sudo apt-get upgrade`. Tester après chaque mise à jour avec un `FIRMWARE_RESTART` Klipper.

---

## 3. Limitation des logs journald

**Problème** : journald sans limite de taille — 182 MB de logs accumulés sur la flash.

**Solution** : limiter à 50 MB, rétention 7 jours, et purger immédiatement.

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo bash -c 'printf "[Journal]\nSystemMaxUse=50M\nSystemKeepFree=100M\nMaxRetentionSec=7day\n" > /etc/systemd/journald.conf.d/limits.conf'
sudo systemctl restart systemd-journald
sudo journalctl --vacuum-size=50M
```

**Résultat** : 182 MB → 49 MB libérés immédiatement (-133 MB).

---

## 4. noatime + commit sur la partition root

**Problème** :
- Sans `noatime`, chaque lecture de fichier déclenche une écriture (mise à jour du timestamp d'accès) — usure inutile de la flash eMMC.
- `commit=120` (2 min) dans le fstab original : trop long, risque de perte de données sur coupure de courant.
- Double virgule `defaults,,` dans fstab (bug cosmétique corrigé).

**Solution** : ajouter `noatime`, réduire `commit` à 60 s.

```
# /etc/fstab — ligne root modifiée
UUID=... / ext4 defaults,noatime,commit=60,errors=remount-ro 0 1
```

Application immédiate sans reboot :
```bash
sudo mount -o remount,noatime /
```

> Le `commit=60` et `noatime` sont actifs au prochain redémarrage complet pour la partition root.

---

## 5. Paramètres sysctl

**Fichier créé** : `/etc/sysctl.d/99-klipper.conf`

```ini
vm.swappiness=10
vm.vfs_cache_pressure=50
```

| Paramètre | Valeur avant | Valeur après | Effet |
|---|---|---|---|
| `vm.swappiness` | 60 | **10** | Le kernel utilise le swap seulement en dernier recours — priorité à la RAM |
| `vm.vfs_cache_pressure` | 100 | **50** | Conserve plus longtemps le cache de répertoires/inodes en RAM |

```bash
sudo bash -c 'printf "vm.swappiness=10\nvm.vfs_cache_pressure=50\n" > /etc/sysctl.d/99-klipper.conf'
sudo sysctl -p /etc/sysctl.d/99-klipper.conf
```

---

## Résumé des gains

| Métrique | Avant | Après |
|---|---|---|
| Swap | aucun | **481 MB** (zram zstd) |
| Journal logs | 182 MB | **49 MB** |
| Espace disque libre | 1.9 GB (73%) | **2.0 GB (71%)** |
| Écritures flash inutiles (atime) | oui | **non** |
| Services inutiles actifs | 4 | **0** |
| Risque mise à jour auto | oui | **non** |
| `vm.swappiness` | 60 | **10** |

---

## Maintenance recommandée

```bash
# Vérifier l'espace disque
df -h /

# Vérifier l'utilisation du swap zram
free -h

# Nettoyer les vieux logs Klipper (garder les 5 derniers)
ls -t ~/printer_data/logs/klippy.log.* | tail -n +6 | xargs rm -f

# Mettre à jour manuellement (après avoir vérifié le changelog)
sudo apt-get update && sudo apt-get upgrade
```
