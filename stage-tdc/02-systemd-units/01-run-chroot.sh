#!/bin/bash -e
set -euo pipefail

# Files were installed into the rootfs by the companion 00-run.sh (non-chroot).
# Here we only enable units — that requires the chroot (talks to the image's
# systemd). scanner-wifi/ble/publisher have ConditionPathExists=/etc/vena-pulse/
# config.json so they no-op until the captive portal writes config; onboarding
# has the negated condition so it ONLY runs while config is absent.
systemctl enable vena-pulse-onboarding.service
systemctl enable vena-pulse-scanner-wifi.service
systemctl enable vena-pulse-scanner-ble.service
systemctl enable vena-pulse-publisher.service
systemctl enable vena-pulse-update.timer

echo "systemd units enabled"
