#!/bin/bash -e
# Bench/debug ergonomics — make a headless Pi observable WITHOUT a network.
# The image bakes no Wi-Fi (PSK in a public-repo image would leak; Sprint C
# ships the captive-portal onboarding), so on the bench the only window into a
# freshly-flashed Pi is a local console. This enables two:
#   - hdmi_force_hotplug=1 : force HDMI text-console output even when no display
#     is detected at boot, or via mini-HDMI adapters that don't assert hotplug.
#   - enable_uart=1        : stabilise the UART so a USB-TTL serial console works
#     on GPIO 14/15 @ 115200 8N1 (RPi OS Lite already puts a login getty on
#     serial0 via the default cmdline). Does NOT disable Bluetooth (BT stays on
#     the PL011), so bleak BLE scanning is unaffected.
# Both are inert in production (nothing attached) and add no attack surface.
set -euo pipefail

CONFIG="${ROOTFS_DIR}/boot/firmware/config.txt"
[ -f "$CONFIG" ] || CONFIG="${ROOTFS_DIR}/boot/config.txt"   # pre-bookworm fallback

append_once() {
  local line="$1"
  grep -qxF "$line" "$CONFIG" || printf '%s\n' "$line" >> "$CONFIG"
}

printf '\n# --- Vena Pulse bench/debug (stage-tdc/04) ---\n' >> "$CONFIG"
append_once "hdmi_force_hotplug=1"
append_once "enable_uart=1"

echo "bench-debug: hdmi_force_hotplug + enable_uart appended to ${CONFIG#${ROOTFS_DIR}}"
