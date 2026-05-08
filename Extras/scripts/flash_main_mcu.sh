#!/bin/bash
# flash_main_mcu.sh — Build and flash J1s main MCU firmware (GD32F307)
#
# Usage (via SSH):
#   bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh
#   bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh --build-only
#
# Options:
#   --build-only   Compile firmware without flashing (no Klipper stop)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "\n${BOLD}==> $*${NC}"; }

BUILD_ONLY=0
[[ "${1}" == "--build-only" ]] && BUILD_ONLY=1

KLIPPER_DIR="$HOME/klipper"
CONFIG="snapmakerj1.config"
FLASH_SCRIPT="scripts/j1_flash_firmware.py"
PORT="/dev/ttyMSM1"
FIRMWARE="out/klipper.bin"

echo ""
echo -e "${BOLD}========================================"
echo    "  J1s MCU Firmware Update"
echo -e "  GD32F307 via SACP protocol"
echo -e "========================================${NC}"
echo ""

# ----------------------------------------
# Prerequisites check
# ----------------------------------------
step "Checking prerequisites"

if [ ! -d "$KLIPPER_DIR/.git" ]; then
    fail "~/klipper not found"
    exit 1
fi
ok "~/klipper found"

if [ ! -f "$KLIPPER_DIR/$CONFIG" ]; then
    fail "$CONFIG not found in ~/klipper/"
    exit 1
fi
ok "Build config: $CONFIG"

if [ ! -f "$KLIPPER_DIR/$FLASH_SCRIPT" ]; then
    fail "$FLASH_SCRIPT not found"
    exit 1
fi
ok "Flash script: $FLASH_SCRIPT"

if [ ! -c "$PORT" ] && [ "$BUILD_ONLY" -eq 0 ]; then
    fail "Serial port $PORT not found — is the printer connected?"
    exit 1
fi
[ "$BUILD_ONLY" -eq 0 ] && ok "Serial port: $PORT"

# ----------------------------------------
# Build
# ----------------------------------------
step "Building Klipper firmware (GD32F307)"
cd "$KLIPPER_DIR"

info "Running: make KCONFIG_CONFIG=$CONFIG -j$(nproc)"
echo ""
make KCONFIG_CONFIG="$CONFIG" -j"$(nproc)"

echo ""
ok "Firmware built: $KLIPPER_DIR/$FIRMWARE ($(du -h $FIRMWARE | cut -f1))"

if [ "$BUILD_ONLY" -eq 1 ]; then
    echo ""
    info "Build-only mode — firmware NOT flashed."
    info "Run without --build-only to flash."
    exit 0
fi

# ----------------------------------------
# Confirmation before stopping Klipper
# ----------------------------------------
step "Ready to flash"
echo ""
warn "Klipper will be STOPPED for the flash operation."
warn "Mainsail will lose connection until Klipper restarts (~30-60 s)."
echo ""
read -r -p "Proceed? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "Aborted — Klipper not stopped, nothing flashed."
    exit 0
fi

# ----------------------------------------
# Stop Klipper
# ----------------------------------------
step "Stopping Klipper"
sudo /usr/bin/systemctl stop klipper
ok "klipper.service stopped"
sleep 1

# ----------------------------------------
# Flash
# ----------------------------------------
step "Flashing firmware via SACP"
info "Sending bootloader trigger on $PORT then flashing..."
echo ""

FLASH_OK=0
if python3 "$FLASH_SCRIPT" --port "$PORT" --klipper "$FIRMWARE"; then
    FLASH_OK=1
fi

echo ""

# ----------------------------------------
# Restart Klipper (always, even on failure)
# ----------------------------------------
step "Restarting Klipper"
sleep 2
sudo /usr/bin/systemctl start klipper
ok "klipper.service started"

# ----------------------------------------
# Result
# ----------------------------------------
echo ""
echo -e "${BOLD}========================================${NC}"
if [ "$FLASH_OK" -eq 1 ]; then
    echo -e "${GREEN}${BOLD}  Firmware update successful!${NC}"
else
    echo -e "${RED}${BOLD}  Flash FAILED — Klipper restarted${NC}"
    echo    "  Check the output above for details."
fi
echo -e "${BOLD}========================================${NC}"
echo ""

[ "$FLASH_OK" -eq 1 ] && exit 0 || exit 1
