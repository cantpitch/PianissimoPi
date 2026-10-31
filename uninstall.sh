#!/usr/bin/env bash
# Removes PianissimoPi. Keeps /etc/pianissimopi.conf and the piano samples
# unless --purge is given.
# Usage: sudo ./uninstall.sh [--purge]
set -euo pipefail

SF_DIR=/usr/local/share/pianissimopi

purge=0
case ${1:-} in
  "") ;;
  --purge) purge=1 ;;
  *) echo "Usage: sudo $0 [--purge]" >&2; exit 2 ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

echo "==> Stopping services"
# Stopping the synth also restores the CPU governor (ExecStopPost).
systemctl disable --now pianissimopi.service 2>/dev/null || true
systemctl stop pianissimopi-connect.service 2>/dev/null || true

echo "==> Removing scripts, services, and udev rule"
rm -f /etc/systemd/system/pianissimopi.service \
      /etc/systemd/system/pianissimopi-connect.service \
      /etc/udev/rules.d/90-pianissimopi-midi.rules \
      /usr/local/bin/pianissimopi-synth \
      /usr/local/bin/pianissimopi-connect \
      /usr/local/bin/pianissimopi-cpu
systemctl daemon-reload
udevadm control --reload-rules

echo "==> Removing service user"
if id pianissimopi &>/dev/null; then
  userdel pianissimopi
fi

if (( purge )); then
  echo "==> Removing settings and piano samples"
  rm -rf "$SF_DIR" /etc/pianissimopi.conf
  kept=""
else
  kept="
Kept your settings (/etc/pianissimopi.conf) and piano samples ($SF_DIR).
Run with --purge to remove them too."
fi

cat <<EOF

PianissimoPi is uninstalled.$kept
FluidSynth and the other packages were left installed. To remove them:
  sudo apt-get remove fluidsynth fluid-soundfont-gm
EOF
