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

# Install into /opt/tdc-pulse-venv (system-wide, not per-user).
# Sprint A always installs from `main` branch HEAD. Sprint E hardens this
# to GitHub Release artifact with cosign verification — risk explicitly
# documented in spec §20 R10 and master plan cross-cutting concerns.
python3 -m venv /opt/tdc-pulse-venv
/opt/tdc-pulse-venv/bin/pip install --upgrade pip wheel
/opt/tdc-pulse-venv/bin/pip install \
  "git+https://github.com/Chaotic-Lab/caos-lab-sbc.git@main#egg=tdc-pulse"

# Symlink Poetry-defined console scripts into /usr/local/bin so systemd
# units can reference stable paths.
for cmd in vena-pulse-scanner-wifi vena-pulse-scanner-ble \
           vena-pulse-publisher vena-pulse-onboarding; do
  ln -sf "/opt/tdc-pulse-venv/bin/$cmd" "/usr/local/bin/$cmd"
done

# Enable bluetoothd --experimental flag (required by bleak passive scan).
# Research finding: bleak BlueZ passive mode REQUIRES this.
# Drop-in override at /etc/systemd/system/.../bluetooth.service.d/
# survives apt upgrades of bluez (sed-editing /lib/systemd/... does NOT).
mkdir -p /etc/systemd/system/bluetooth.service.d
cat > /etc/systemd/system/bluetooth.service.d/10-experimental.conf <<'EOF'
[Service]
# Blank ExecStart= clears the upstream value before re-adding (systemd idiom).
ExecStart=
ExecStart=/usr/lib/bluetooth/bluetoothd --experimental
EOF

# Hold kernel packages so unattended-upgrades cannot break DKMS rebuild
# silently. Research finding: DKMS auto-rebuilds on kernel install but only
# if headers are present + version-matched. We hold to AVOID the race window
# between kernel install and headers install during unattended-upgrades.
# Manual ops upgrade kernel + headers together when needed.
apt-mark hold raspberrypi-kernel raspberrypi-kernel-headers || true
# linux-image-rpi-v8 / linux-image-rpi-2712 are the actual binary kernels
# on Bookworm 64-bit Pi Zero 2 W. Hold both proactively (apt-mark on a
# non-installed package is a no-op error which `|| true` swallows).
apt-mark hold linux-image-rpi-v8 || true
apt-mark hold linux-image-rpi-2712 || true

# Disable unattended-upgrades on kernel pkgs as belt-and-suspenders.
cat > /etc/apt/apt.conf.d/51unattended-upgrades-kernel-blacklist <<'EOF'
Unattended-Upgrade::Package-Blacklist {
    "linux-image-.*";
    "raspberrypi-kernel.*";
};
EOF

echo "tdc-pulse-py installed at /opt/tdc-pulse-venv; kernel pinned."
