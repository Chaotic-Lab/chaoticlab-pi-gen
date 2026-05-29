#!/bin/bash -e
# Non-chroot file installer (see 02-systemd-units/00-run.sh for why /tmp/files
# does not exist inside the chroot). Install the first-boot script + unit into
# the rootfs from the host side; 01-run-chroot.sh only enables the unit.
set -euo pipefail

install -m 0755 files/firstboot.sh "${ROOTFS_DIR}/usr/local/sbin/vena-pulse-firstboot"
install -m 0644 files/vena-pulse-firstboot.service "${ROOTFS_DIR}/etc/systemd/system/"

echo "first-boot script + unit installed into rootfs"
