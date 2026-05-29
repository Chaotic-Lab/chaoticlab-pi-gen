#!/bin/bash -e
set -euo pipefail

# Script + unit were installed into the rootfs by the companion 00-run.sh.
# Enabling requires the chroot.
systemctl enable vena-pulse-firstboot.service

echo "first-boot unit enabled"
