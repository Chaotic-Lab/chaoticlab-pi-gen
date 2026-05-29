#!/bin/bash -e
# Non-chroot file installer. pi-gen does NOT stage a sub-stage's files/ dir into
# the chroot (on_chroot pipes only the script), so there is no /tmp/files inside
# the chroot. We install directly into ${ROOTFS_DIR} from the host side here;
# 01-run-chroot.sh then only runs chroot-requiring commands (systemctl enable).
set -euo pipefail

DEST="${ROOTFS_DIR}/etc/systemd/system"
install -m 644 files/vena-pulse-scanner-wifi.service "${DEST}/"
install -m 644 files/vena-pulse-scanner-ble.service  "${DEST}/"
install -m 644 files/vena-pulse-publisher.service    "${DEST}/"
install -m 644 files/vena-pulse-onboarding.service   "${DEST}/"
install -m 644 files/vena-pulse-update.timer         "${DEST}/"
install -m 644 files/vena-pulse-update.service       "${DEST}/"

# Persistent NetworkManager unmanaged config for wlan1 — drops the runtime
# nmcli ExecStartPre from the scanner-wifi unit (fragile if NM not ready)
# in favor of a static config that survives NM restarts.
install -d "${ROOTFS_DIR}/etc/NetworkManager/conf.d"
cat > "${ROOTFS_DIR}/etc/NetworkManager/conf.d/99-vena-wlan1-unmanaged.conf" <<'EOF'
# Vena Pulse — keep wlan1 out of NetworkManager so monitor mode is stable.
# Also lock by USB driver so renamed (wlxAABBCC...) interfaces are covered.
[keyfile]
unmanaged-devices=interface-name:wlan1;driver:88x2bu
EOF

# Static systemd .link file pins ANY USB Wi-Fi adapter using the 88x2bu driver
# to the predictable name "wlan1". Survives first-boot before the dongle is even
# plugged in. Driver= match is keyed off udev property ID_NET_DRIVER.
install -d "${ROOTFS_DIR}/etc/systemd/network"
cat > "${ROOTFS_DIR}/etc/systemd/network/10-vena-wlan1.link" <<'EOF'
[Match]
Driver=88x2bu

[Link]
Name=wlan1
EOF

echo "systemd units + NM unmanaged + .link iface pin installed into rootfs"
