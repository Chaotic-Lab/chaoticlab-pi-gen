#!/bin/bash -e
# Non-chroot installer (pi-gen does not stage files/ into the chroot — see
# 02-systemd-units/00-run.sh). CI (build-image.yml) builds the tdc-pulse wheel
# from the PRIVATE chaoticlab-sbc repo into files/ (gitignored). We copy it into
# the rootfs so the chroot installs locally — keeps chaoticlab-sbc private (no
# git clone of the private repo from inside the image).
set -euo pipefail
shopt -s nullglob

wheels=(files/*.whl)
if [ ${#wheels[@]} -eq 0 ]; then
  echo "ERROR: no tdc-pulse wheel in $(pwd)/files/." >&2
  echo "       build-image.yml must build it (python -m build) before pi-gen runs." >&2
  exit 1
fi

install -d "${ROOTFS_DIR}/opt/tdc-pulse-wheels"
cp "${wheels[@]}" "${ROOTFS_DIR}/opt/tdc-pulse-wheels/"
echo "staged ${#wheels[@]} wheel(s) into rootfs /opt/tdc-pulse-wheels"
