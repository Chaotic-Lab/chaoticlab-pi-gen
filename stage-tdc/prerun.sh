#!/bin/bash -e
# Standard pi-gen custom-stage prerun: seed this stage's rootfs from the
# previous stage's work dir. Required for any appended stage (stage-tdc runs
# after stage2); without it ${ROOTFS_DIR} is empty and the chroot scripts fail.
if [ ! -d "${ROOTFS_DIR}" ]; then
	copy_previous
fi
