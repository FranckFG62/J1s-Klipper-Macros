# Armbian Optimisations — Snapmaker J1 / J1s

Optimisations applied to the J1s embedded Armbian host (Qualcomm MSM8909, 962 MB RAM).

> 🖥️ **System**: Armbian 26.2.1 Trixie (Debian 13) — kernel `6.12.1-snapmakerj1-msm8909`

> 🇫🇷 Une version française est disponible dans [Armbian_Optimisations_FR.md](Armbian_Optimisations_FR.md).

---

## 1. zram swap

**Problem**: no swap configured. With 962 MB of RAM, a simultaneous Klipper + Moonraker + KlipperScreen spike can trigger an OOM kill.

**Solution**: zram-swap (RAM-compressed swap via zstd — faster and less wear than flash-based swap).

```bash
sudo apt-get install -y zram-tools
sudo bash -c 'printf "ALGO=zstd\nPERCENT=50\n" > /etc/default/zramswap'
sudo systemctl enable --now zramswap
```

**Result**: 481 MB of swap available without touching the flash storage.

---

## 2. Disabling unnecessary services

**Problem**: several services running that serve no purpose on a 3D printer — wasted memory, open network ports, and risk of automatic updates breaking Klipper.

| Service | Reason for disabling |
|---|---|
| `nfs-blkmap` | NFS block layout service — useless on a 3D printer |
| `rpcbind` | NFS portmapper — useless |
| `vnstat` | Network traffic monitor — not needed |
| `unattended-upgrades` | Auto-updates — risk of breaking Klipper or the custom kernel |

```bash
sudo systemctl stop nfs-blkmap rpcbind vnstat unattended-upgrades
sudo systemctl disable nfs-blkmap rpcbind vnstat unattended-upgrades
```

> ⚠️ System updates can still be performed manually via `sudo apt-get update && sudo apt-get upgrade`. Always test after an update with a Klipper `FIRMWARE_RESTART`.

---

## 3. journald log size limits

**Problem**: journald without size limits — 182 MB of logs accumulated on flash storage.

**Solution**: cap at 50 MB, 7-day retention, and vacuum immediately.

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo bash -c 'printf "[Journal]\nSystemMaxUse=50M\nSystemKeepFree=100M\nMaxRetentionSec=7day\n" > /etc/systemd/journald.conf.d/limits.conf'
sudo systemctl restart systemd-journald
sudo journalctl --vacuum-size=50M
```

**Result**: 182 MB → 49 MB — 133 MB freed immediately.

---

## 4. noatime + commit on the root partition

**Problem**:
- Without `noatime`, every file read triggers a write (access timestamp update) — unnecessary wear on the eMMC flash.
- `commit=120` (2 min) in the original fstab: too long, risk of data loss on power failure.
- Double comma `defaults,,` in fstab (cosmetic bug, also fixed).

**Solution**: add `noatime`, reduce `commit` to 60 s.

```
# /etc/fstab — modified root line
UUID=... / ext4 defaults,noatime,commit=60,errors=remount-ro 0 1
```

Apply immediately without reboot:
```bash
sudo mount -o remount,noatime /
```

> `commit=60` and `noatime` take full effect on the root partition after the next reboot.

---

## 5. sysctl tuning

**File created**: `/etc/sysctl.d/99-klipper.conf`

```ini
vm.swappiness=10
vm.vfs_cache_pressure=50
```

| Parameter | Before | After | Effect |
|---|---|---|---|
| `vm.swappiness` | 60 | **10** | Kernel uses swap only as a last resort — RAM is preferred |
| `vm.vfs_cache_pressure` | 100 | **50** | Keeps directory/inode cache in RAM longer |

```bash
sudo bash -c 'printf "vm.swappiness=10\nvm.vfs_cache_pressure=50\n" > /etc/sysctl.d/99-klipper.conf'
sudo sysctl -p /etc/sysctl.d/99-klipper.conf
```

---

## Summary

| Metric | Before | After |
|---|---|---|
| Swap | none | **481 MB** (zram zstd) |
| Journal logs | 182 MB | **49 MB** |
| Free disk space | 1.9 GB (73%) | **2.0 GB (71%)** |
| Unnecessary flash writes (atime) | yes | **no** |
| Unnecessary active services | 4 | **0** |
| Auto-update risk | yes | **no** |
| `vm.swappiness` | 60 | **10** |

---

## Recommended maintenance

```bash
# Check disk space
df -h /

# Check zram swap usage
free -h

# Clean up old Klipper logs (keep the 5 most recent)
ls -t ~/printer_data/logs/klippy.log.* | tail -n +6 | xargs rm -f

# Update manually (after checking the changelog)
sudo apt-get update && sudo apt-get upgrade
```
