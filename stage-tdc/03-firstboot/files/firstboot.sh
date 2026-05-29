#!/bin/bash -e
# Vena Pulse first-boot setup. Runs ONCE on first boot via systemd unit
# (self-disabled after success). Idempotent on partial failure — any failed
# stage writes /etc/vena-pulse/firstboot.error.json without exiting non-zero
# so bench-test can surface the failure without breaking other boots.

set -uo pipefail   # NOTE: no -e so partial failures get logged not aborted
LOG=/var/log/vena-pulse-firstboot.log
ERROR_FILE=/etc/vena-pulse/firstboot.error.json
exec > >(tee -a "$LOG") 2>&1

mkdir -p /etc/vena-pulse

write_error() {
  local stage="$1"; local msg="$2"
  cat > "$ERROR_FILE" <<EOF
{
  "stage": "$stage",
  "message": "$msg",
  "kernel": "$(uname -r)",
  "ts": "$(date -Iseconds)"
}
EOF
}

echo "[firstboot] $(date -Iseconds) starting"

# 1) Generate device_id from primary MAC (Pi Zero 2 W has no eth0; use wlan0).
MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null \
      || cat /sys/class/net/eth0/address 2>/dev/null \
      || printf '00:00:00:00:00:00')
# printf avoids the trailing newline that echo would add (caught by tail -c).
LAST6=$(printf '%s' "$MAC" | tr -d ':' | tr 'a-f' 'A-F' | tail -c 6)
DEVICE_ID="pulse-${LAST6}"
echo "[firstboot] device_id=$DEVICE_ID (from MAC $MAC)"

# 2) Persist identity file. Parse VERSION_ID cleanly (strip quotes + key).
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' \
             || printf 'unknown')
cat > /etc/vena-pulse/identity.json <<EOF
{
  "device_id": "$DEVICE_ID",
  "mac_primary": "$MAC",
  "sku": "pulse",
  "fw_image_os_version": "$OS_VERSION",
  "fw_image_built_at": "$(date -Iseconds)"
}
EOF
chmod 0644 /etc/vena-pulse/identity.json

# 3) Force DKMS rebuild of rtl88x2bu against the running kernel.
KVER=$(uname -r)
echo "[firstboot] running kernel: $KVER"

# Wait up to 60s for kernel headers tree to be present. apt may still be
# settling on first boot (pi-gen runs raspberrypi-kernel-headers in chroot
# but the BUILT artifact may be mis-versioned for the booted kernel).
for i in $(seq 1 12); do
  if [ -d "/lib/modules/$KVER/build" ]; then break; fi
  echo "[firstboot] waiting for /lib/modules/$KVER/build (attempt $i/12)..."
  sleep 5
done

if [ ! -d "/lib/modules/$KVER/build" ]; then
  echo "[firstboot] headers missing; attempting on-demand install"
  apt-get update -qq || true
  # Bookworm renamed RPi kernel/header packages to linux-{image,headers}-rpi-*.
  # Try the exact-version package first, then the v8 meta, then the legacy name.
  apt-get install -y --no-install-recommends "linux-headers-${KVER}" \
    || apt-get install -y --no-install-recommends linux-headers-rpi-v8 \
    || apt-get install -y --no-install-recommends raspberrypi-kernel-headers \
    || true
fi

if [ ! -d "/lib/modules/$KVER/build" ]; then
  write_error "headers" "kernel headers absent for $KVER after 60s + apt install"
  echo "[firstboot] FATAL: no headers — Pi will boot but Archer T3U Plus will be inert"
else
  if ! dkms status -m rtl88x2bu -k "$KVER" 2>/dev/null | grep -q installed; then
    echo "[firstboot] building rtl88x2bu for $KVER"
    if ! dkms autoinstall -k "$KVER"; then
      write_error "dkms-autoinstall" "see /var/lib/dkms/rtl88x2bu/*/build/make.log"
    fi
  fi
fi

# 4) Iface pinning lives in baked .link file (Driver=88x2bu match), set in
#    pi-gen Task 13. firstboot does NOT need to write a MAC-based override.

# 5) Self-disable so this doesn't run again.
systemctl disable vena-pulse-firstboot.service
touch /etc/vena-pulse/firstboot.done

if [ -f "$ERROR_FILE" ]; then
  echo "[firstboot] complete WITH ERRORS — see $ERROR_FILE"
  exit 0   # do NOT fail the unit; bench-test surfaces error.json
else
  echo "[firstboot] complete OK"
fi
