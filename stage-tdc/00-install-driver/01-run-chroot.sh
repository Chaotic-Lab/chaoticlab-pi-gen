#!/bin/bash -e
# Install morrownr/88x2bu-20210702 DKMS source for RTL8812BU (TP-Link Archer
# T3U Plus). DKMS BUILD is deferred to first-boot because pi-gen chroot
# kernel != target Pi kernel. PACKAGE_NAME="rtl88x2bu" (DKMS); BUILT_MODULE
# is 88x2bu (loaded module). Bench checks both names. Research finding §R7.

set -euo pipefail

# Globally disable apt recommends BEFORE any apt operation — research
# CRITICAL finding: dkms install without this can pull Debian arm64 kernel.
# Survives to first-boot so dkms autoinstall + raspberrypi-kernel-headers
# auto-fetch also obey the policy.
cat > /etc/apt/apt.conf.d/99-no-recommends <<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

# Defensive: if somehow Debian arm64 kernel snuck in via a prior step, drop it.
if dpkg -l linux-image-arm64 2>/dev/null | grep -q ^ii; then
  echo "WARN: linux-image-arm64 installed; removing to keep rpi kernel as default"
  apt-get remove -y --purge linux-image-arm64 || true
fi

# Blacklist the in-kernel rtw88_8822bu so morrownr's out-of-tree driver wins.
# Research finding: in-tree driver lacks reliable monitor mode.
cat > /etc/modprobe.d/blacklist-rtw88.conf <<'EOF'
# Vena Pulse uses morrownr/88x2bu-20210702 with monitor mode.
# Mainline rtw88_8822bu does NOT expose monitor → must be blacklisted.
blacklist rtw88_8822bu
EOF

cd /tmp
rm -rf 88x2bu-20210702
git clone --depth 1 https://github.com/morrownr/88x2bu-20210702.git
cd 88x2bu-20210702

# Pin to a known-good version (avoids regex fragility on VERSION file).
# Bump on driver upgrade after running bench-test.md end-to-end.
DRV_VER="5.13.1"

mkdir -p "/usr/src/rtl88x2bu-${DRV_VER}"
cp -r ./* "/usr/src/rtl88x2bu-${DRV_VER}/"

# Generate dkms.conf if not present
if [ ! -f "/usr/src/rtl88x2bu-${DRV_VER}/dkms.conf" ]; then
  cat > "/usr/src/rtl88x2bu-${DRV_VER}/dkms.conf" <<EOF
PACKAGE_NAME="rtl88x2bu"
PACKAGE_VERSION="${DRV_VER}"
MAKE[0]="make -j\$(nproc) KSRC=/lib/modules/\${kernelver}/build"
CLEAN="make clean"
BUILT_MODULE_NAME[0]="88x2bu"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/wireless"
AUTOINSTALL="yes"
EOF
fi

# Register with DKMS idempotently — do NOT build here (chroot kernel mismatch).
if dkms status -m rtl88x2bu 2>/dev/null | grep -q "${DRV_VER}"; then
  echo "rtl88x2bu/${DRV_VER} already in DKMS tree; skipping add"
else
  dkms add "rtl88x2bu/${DRV_VER}"
fi

# Install monitor-mode-friendly module options
cat > /etc/modprobe.d/88x2bu.conf <<'EOF'
# Vena Pulse — monitor mode friendly
# rtw_drv_log_level=0 reduces dmesg spam; rtw_ips_mode=0 disables power save
options 88x2bu rtw_drv_log_level=0 rtw_ips_mode=0
EOF

# Cleanup
cd /
rm -rf /tmp/88x2bu-20210702
echo "rtl88x2bu DKMS source installed; will auto-build on first boot."
