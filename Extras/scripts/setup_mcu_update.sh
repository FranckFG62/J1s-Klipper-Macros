#!/bin/bash
# setup_mcu_update.sh — One-time setup for MCU update scripts on the Snapmaker J1s
#
# Run once via SSH after deploying the repo to ~/printer_data/config/:
#   bash ~/printer_data/config/Extras/scripts/setup_mcu_update.sh
#
# What this script does:
#   1. Fixes the Klipper repo "dirty" state (snapmakerj1 fork specifics)
#   2. Adds a passwordless sudoers rule for Klipper service control
#   3. Makes the flash scripts executable

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail() { echo -e "${RED}[ERROR]${NC} $*"; }
step() { echo -e "\n${BOLD}==> $*${NC}"; }

echo ""
echo -e "${BOLD}========================================"
echo    "  J1s MCU Update — One-time Setup"
echo -e "========================================${NC}"
echo ""

# ----------------------------------------
# 1. Fix Klipper repo dirty state
# ----------------------------------------
step "Step 1/3 — Klipper repo cleanup"

KLIPPER_DIR="$HOME/klipper"
if [ ! -d "$KLIPPER_DIR/.git" ]; then
    warn "~/klipper not found or not a git repo — skipping repo cleanup"
else
    cd "$KLIPPER_DIR"

    # Restore src/Kconfig if modified (may have been changed for RP2040 compilation)
    if ! git diff --quiet src/Kconfig 2>/dev/null; then
        git checkout src/Kconfig
        ok "src/Kconfig restored"
    else
        ok "src/Kconfig already clean"
    fi

    # skip-worktree for deleted src/avr/* files (intentionally removed by snapmakerj1 fork)
    AVR_FILES=$(git ls-files src/avr/ 2>/dev/null)
    if [ -n "$AVR_FILES" ]; then
        echo "$AVR_FILES" | xargs git update-index --skip-worktree
        ok "src/avr/ deleted files ignored (--skip-worktree)"
    else
        ok "src/avr/ already clean"
    fi

    # Add untracked fork-specific and build files to local git exclude
    EXCLUDE_FILE=".git/info/exclude"
    MARKER="# J1s fork excludes"

    if ! grep -q "$MARKER" "$EXCLUDE_FILE" 2>/dev/null; then
        cat >> "$EXCLUDE_FILE" << 'EOF'
# J1s fork excludes — added by setup_mcu_update.sh
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
        ok "Untracked fork files added to .git/info/exclude"
    else
        ok ".git/info/exclude already configured"
    fi

    # Verify result
    if git status --porcelain | grep -q .; then
        warn "Repo still has changes — run 'cd ~/klipper && git status' to investigate"
    else
        ok "Klipper repo is clean — Moonraker updates will work"
    fi
fi

# ----------------------------------------
# 2. Sudoers rule for Klipper service
# ----------------------------------------
step "Step 2/3 — Passwordless sudo for Klipper service"

SUDOERS_FILE="/etc/sudoers.d/klipper-flash"
SYSTEMCTL_PATH=$(which systemctl)
SUDOERS_LINE="pi ALL=(ALL) NOPASSWD: ${SYSTEMCTL_PATH} stop klipper, ${SYSTEMCTL_PATH} start klipper, ${SYSTEMCTL_PATH} restart klipper"

if [ -f "$SUDOERS_FILE" ] && grep -q "NOPASSWD" "$SUDOERS_FILE" 2>/dev/null; then
    ok "Sudoers rule already in place ($SUDOERS_FILE)"
else
    if echo "$SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" > /dev/null \
       && sudo chmod 440 "$SUDOERS_FILE" \
       && sudo visudo -c -f "$SUDOERS_FILE" 2>/dev/null; then
        ok "Sudoers rule added ($SUDOERS_FILE)"
    else
        sudo rm -f "$SUDOERS_FILE" 2>/dev/null || true
        warn "Could not write sudoers file — flash script will prompt for sudo password"
    fi
fi

# ----------------------------------------
# 3. Script permissions
# ----------------------------------------
step "Step 3/3 — Script permissions"

SCRIPTS_DIR="$HOME/printer_data/config/Extras/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    chmod +x "$SCRIPTS_DIR"/*.sh
    ok "Scripts in $SCRIPTS_DIR are executable"
else
    fail "$SCRIPTS_DIR not found — deploy the repo to ~/printer_data/config/ first"
    exit 1
fi

# ----------------------------------------
# Done
# ----------------------------------------
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  Setup complete!${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo "  Available scripts (run via SSH):"
echo ""
echo -e "  ${CYAN}bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh${NC}"
echo    "    Build + flash J1s main MCU (GD32F307)"
echo    "    Klipper is stopped automatically during flash"
echo ""
echo -e "  ${CYAN}bash ~/printer_data/config/Extras/scripts/flash_main_mcu.sh --build-only${NC}"
echo    "    Build firmware only, no flash"
echo ""
echo -e "  ${CYAN}bash ~/printer_data/config/Extras/scripts/build_mmb_firmware.sh${NC}"
echo    "    Build RP2040 firmware for BTT MMB Cubic"
echo    "    Flash manually via USB mass storage (instructions shown after build)"
echo ""
