#!/bin/bash -e
# Install tdc-pulse-py + harden bluetoothd + pin kernel against autoupdates.

set -euo pipefail

# Service user with no shell, no home directory.
# `bluez` package (installed via 00-packages above) creates the 'bluetooth'
# group we add vena-pulse to here. Ordering is enforced by pi-gen's
# packages-before-script convention.
adduser --quiet --system --group --no-create-home --shell /usr/sbin/nologin vena-pulse
adduser --quiet vena-pulse bluetooth
adduser --quiet vena-pulse netdev   # required for Wi-Fi scanner ambient caps

# Create runtime dirs (also created at runtime by systemd RuntimeDirectory= /
# StateDirectory= but we pre-create for clarity)
mkdir -p /etc/vena-pulse /var/lib/vena-pulse /run/vena-pulse
chown vena-pulse:vena-pulse /var/lib/vena-pulse /run/vena-pulse
chmod 0750 /etc/vena-pulse /var/lib/vena-pulse /run/vena-pulse

# Install into /opt/tdc-pulse-venv (system-wide, not per-user) from the LOCAL
# wheel staged by 00-run.sh (CI built it from the private chaoticlab-sbc repo).
# This keeps chaoticlab-sbc PRIVATE — the image never clones it. Runtime deps
# (scapy/bleak/etc.) still resolve from public PyPI during this install.
# Sprint E hardens further: cosign-verified wheel pulled from MinIO.
python3 -m venv /opt/tdc-pulse-venv
/opt/tdc-pulse-venv/bin/pip install --upgrade pip wheel
/opt/tdc-pulse-venv/bin/pip install /opt/tdc-pulse-wheels/*.whl

# Symlink Poetry-defined console scripts into /usr/local/bin so systemd
# units can reference stable paths.
for cmd in vena-pulse-scanner-wifi vena-pulse-scanner-ble \
           vena-pulse-publisher vena-pulse-onboarding; do
  ln -sf "/opt/tdc-pulse-venv/bin/$cmd" "/usr/local/bin/$cmd"
done

# Enable bluetoothd --experimental flag (required by bleak passive scan).
# Research finding: bleak BlueZ passive mode REQUIRES this.
# Drop-in override survives apt upgrades of bluez (sed-editing /lib/systemd/...
# does NOT). The bluetoothd binary path differs across Debian releases
# (Bookworm = /usr/libexec/bluetooth/bluetoothd; older = /usr/lib/bluetooth/
# bluetoothd), so detect the real path inside the chroot instead of hardcoding.
BTD_PATH="$(command -v bluetoothd 2>/dev/null || true)"
if [ -z "$BTD_PATH" ]; then
  for c in /usr/libexec/bluetooth/bluetoothd /usr/lib/bluetooth/bluetoothd; do
    [ -x "$c" ] && BTD_PATH="$c" && break
  done
fi
[ -z "$BTD_PATH" ] && BTD_PATH=/usr/libexec/bluetooth/bluetoothd
echo "bluetoothd path resolved to: $BTD_PATH"
mkdir -p /etc/systemd/system/bluetooth.service.d
cat > /etc/systemd/system/bluetooth.service.d/10-experimental.conf <<EOF
[Service]
# Blank ExecStart= clears the upstream value before re-adding (systemd idiom).
ExecStart=
ExecStart=${BTD_PATH} --experimental
EOF

# Hold kernel packages so unattended-upgrades cannot break DKMS rebuild
# silently. Research finding: DKMS auto-rebuilds on kernel install but only
# if headers are present + version-matched. We hold to AVOID the race window
# between kernel install and headers install during unattended-upgrades.
# Manual ops upgrade kernel + headers together when needed.
# (apt-mark hold on a non-installed package is a no-op error which `|| true`
# swallows — so listing legacy names alongside Bookworm names is harmless.)
apt-mark hold linux-image-rpi-v8 linux-headers-rpi-v8 || true
apt-mark hold linux-image-rpi-2712 linux-headers-rpi-2712 || true
apt-mark hold raspberrypi-kernel raspberrypi-kernel-headers || true

# Disable unattended-upgrades on kernel pkgs as belt-and-suspenders.
cat > /etc/apt/apt.conf.d/51unattended-upgrades-kernel-blacklist <<'EOF'
Unattended-Upgrade::Package-Blacklist {
    "linux-image-.*";
    "linux-headers-.*";
    "raspberrypi-kernel.*";
};
EOF

echo "tdc-pulse-py installed at /opt/tdc-pulse-venv; kernel pinned."
