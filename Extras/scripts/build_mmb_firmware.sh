#!/bin/bash
# build_mmb_firmware.sh — Build Klipper RP2040 firmware for BTT MMB Cubic V1.0
#
# Usage (via SSH):
#   bash ~/printer_data/config/Extras/scripts/build_mmb_firmware.sh
#
# After building, flash manually:
#   1. Hold BOOT button on MMB Cubic, plug USB cable
#   2. A mass storage drive appears (RPI-RP2)
#   3. Copy ~/klipper/out/klipper.uf2 to the drive
#   4. Board reboots automatically

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
fail() { echo -e "${RED}[ERROR]${NC} $*"; }
step() { echo -e "\n${BOLD}==> $*${NC}"; }

KLIPPER_DIR="$HOME/klipper"
CONFIG=".config.rp2040"
FIRMWARE="out/klipper.uf2"

echo ""
echo -e "${BOLD}========================================"
echo    "  MMB Cubic Firmware Build"
echo -e "  RP2040 (Klipper UF2)"
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
    echo ""
    info "To create it, run from ~/klipper/:"
    info "  make KCONFIG_CONFIG=.config.rp2040 menuconfig"
    info "Select: Micro-controller = Raspberry Pi RP2040"
    exit 1
fi
ok "Build config: $CONFIG"

# ----------------------------------------
# Build
# ----------------------------------------
step "Building Klipper firmware (RP2040)"
cd "$KLIPPER_DIR"

info "Running: make KCONFIG_CONFIG=$CONFIG -j$(nproc)"
echo ""
make KCONFIG_CONFIG="$CONFIG" -j"$(nproc)"

echo ""
ok "Firmware built: $KLIPPER_DIR/$FIRMWARE ($(du -h $FIRMWARE | cut -f1))"

# ----------------------------------------
# Flash instructions
# ----------------------------------------
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  Build successful!${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo -e "  Firmware: ${BOLD}$KLIPPER_DIR/$FIRMWARE${NC}"
echo ""
echo    "  To flash the MMB Cubic:"
echo    "    1. Hold the BOOT button on the MMB Cubic"
echo    "    2. Plug in the USB cable — drive RPI-RP2 appears"
echo    "    3. Copy the UF2 file to the drive:"
echo ""
echo -e "       ${CYAN}cp $KLIPPER_DIR/$FIRMWARE /media/pi/RPI-RP2/${NC}"
echo ""
echo    "    4. Board reboots automatically — done."
echo ""
