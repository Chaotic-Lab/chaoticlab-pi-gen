# caos-lab-pi-gen

Custom Raspberry Pi OS image baker for the ChaoticLab **Vena Pulse** SBC SKU.

Wraps the official [RPi-Distro/pi-gen](https://github.com/RPi-Distro/pi-gen) via
[usimd/pi-gen-action](https://github.com/usimd/pi-gen-action) in GitHub Actions.

## What this produces

A Bookworm 64-bit minimal Lite image (~600MB compressed) with:

1. Pre-installed [morrownr/88x2bu-20210702](https://github.com/morrownr/88x2bu-20210702) DKMS driver for TP-Link Archer T3U Plus (RTL8812BU dual-band Wi-Fi)
2. Pre-installed `tdc-pulse-py` (from GitHub Releases of [Chaotic-Lab/caos-lab-sbc](https://github.com/Chaotic-Lab/caos-lab-sbc))
3. Pre-installed 4 systemd unit files for `vena-pulse-{scanner-wifi,scanner-ble,publisher,onboarding}`
4. First-boot script that gates onboarding behind `!/etc/vena-pulse/config.json`

## Build channels

- `nightly/` — cron daily 03:00 BRT, pushed to `s3.chaoticlab.cloud/datapool-tdc/firmware/pulse/nightly/`
- `stable/` — tag push `v*.*.*`, pushed to `s3.chaoticlab.cloud/datapool-tdc/firmware/pulse/stable/`

## Manual trigger

Use GitHub Actions UI → "Build Pi OS Image" → Run workflow.

## Private-repo design

Both `caos-lab-pi-gen` and `caos-lab-sbc` are **private** (the IP is not exposed)
while keeping the convenience of a public CI:

- The image is built on `ubuntu-latest` (x86) with QEMU/binfmt — pi-gen
  cross-builds the aarch64 image. Free GitHub-hosted `ubuntu-24.04-arm` runners
  are public-repo-only, so we don't use them; private repos use normal free minutes.
- `tdc-pulse` is **not** cloned from the private `caos-lab-sbc` inside the image.
  CI checks out `caos-lab-sbc` with a read-only token, builds the wheel, and
  bakes the local wheel into the image. The Pi/chroot never touches the private repo.

## Required GitHub secrets

Set in repo Settings → Secrets and variables → Actions:

- `PI_DEFAULT_PASSWORD` — random 20-char string (ops resets via portal anyway)
- `OPS_SSH_PUBKEY` — authorized `ssh-ed25519` key for emergency access
- `MINIO_ACCESS_KEY` — MinIO IAM user `pi-gen-ci` with write to `s3://datapool-tdc/firmware/pulse/`
- `MINIO_SECRET_KEY`
- `SBC_READ_TOKEN` — fine-grained PAT (or deploy token) with **read-only Contents**
  on `Chaotic-Lab/caos-lab-sbc`, so CI can clone + build the wheel from the private lib
