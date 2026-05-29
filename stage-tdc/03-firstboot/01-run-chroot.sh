#!/bin/bash -e
set -euo pipefail

install -m 0755 /tmp/files/firstboot.sh /usr/local/sbin/vena-pulse-firstboot
install -m 0644 /tmp/files/vena-pulse-firstboot.service /etc/systemd/system/

systemctl enable vena-pulse-firstboot.service

echo "first-boot script + unit installed"
