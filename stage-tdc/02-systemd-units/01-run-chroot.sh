#!/bin/bash -e
set -euo pipefail

SRC=/tmp/files
DEST=/etc/systemd/system

cp "${SRC}"/vena-pulse-scanner-wifi.service "${DEST}/"
cp "${SRC}"/vena-pulse-scanner-ble.service  "${DEST}/"
cp "${SRC}"/vena-pulse-publisher.service    "${DEST}/"
cp "${SRC}"/vena-pulse-onboarding.service   "${DEST}/"
cp "${SRC}"/vena-pulse-update.timer         "${DEST}/"
cp "${SRC}"/vena-pulse-update.service       "${DEST}/"

# Persistent NetworkManager unmanaged config for wlan1 — drops the runtime
# nmcli ExecStartPre from the scanner-wifi unit (fragile if NM not ready)
# in favor of a static config that survives NM restarts.
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/99-vena-wlan1-unmanaged.conf <<'EOF'
# Vena Pulse — keep wlan1 out of NetworkManager so monitor mode is stable.
# Also lock by USB driver so renamed (wlxAABBCC...) interfaces are covered.
[keyfile]
unmanaged-devices=interface-name:wlan1;driver:88x2bu
EOF

# Static systemd .link file pins ANY USB Wi-Fi adapter using the 88x2bu
# driver to the predictable name "wlan1". Survives first-boot before the
# dongle is even plugged in (vs. firstboot MAC-based pin which only works
# if dongle is present at first boot). Driver= match is keyed off udev
# property ID_NET_DRIVER from the in-kernel struct net_device->driver.
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-vena-wlan1.link <<'EOF'
[Match]
Driver=88x2bu

[Link]
Name=wlan1
EOF

# Enable units — they will start on first boot. scanner-wifi/ble/publisher
# have ConditionPathExists=/etc/vena-pulse/config.json so they no-op until
# the captive portal writes config. onboarding has the negated condition
# so it ONLY runs while config is absent.
systemctl enable vena-pulse-onboarding.service
systemctl enable vena-pulse-scanner-wifi.service
systemctl enable vena-pulse-scanner-ble.service
systemctl enable vena-pulse-publisher.service
systemctl enable vena-pulse-update.timer

echo "systemd units + NM unmanaged + .link iface pin installed"
