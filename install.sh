#!/usr/bin/env bash
# PianissimoPi installer for Raspberry Pi OS (Bookworm or later, Lite recommended).
# Usage: sudo ./install.sh
set -euo pipefail

SALAMANDER_URL="https://freepats.zenvoid.org/Piano/SalamanderGrandPiano/SalamanderGrandPiano-SF2-V3+20200602.tar.xz"
SF_DIR=/usr/local/share/pianissimopi
HERE=$(cd "$(dirname "$0")" && pwd)

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

echo "==> Installing packages"
apt-get update
# fluid-soundfont-gm is a fallback piano if the Salamander download fails.
apt-get install -y --no-install-recommends fluidsynth alsa-utils fluid-soundfont-gm curl xz-utils

echo "==> Creating service user"
if ! id pianissimopi &>/dev/null; then
  useradd --system --no-create-home --shell /usr/sbin/nologin --groups audio pianissimopi
fi

echo "==> Installing grand piano soundfont"
mkdir -p "$SF_DIR"
if [[ ! -e $SF_DIR/piano.sf2 ]]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  if curl -fL --retry 3 -o "$tmp/salamander.tar.xz" "$SALAMANDER_URL"; then
    tar -xJf "$tmp/salamander.tar.xz" -C "$tmp"
    sf2=$(find "$tmp" -name '*.sf2' -print -quit)
    install -m 0644 "$sf2" "$SF_DIR/SalamanderGrandPiano.sf2"
    ln -sf "$SF_DIR/SalamanderGrandPiano.sf2" "$SF_DIR/piano.sf2"
  else
    echo "Salamander download failed; falling back to FluidR3 GM piano" >&2
    ln -sf /usr/share/sounds/sf2/FluidR3_GM.sf2 "$SF_DIR/piano.sf2"
  fi
fi

echo "==> Installing scripts, config, and services"
install -m 0755 "$HERE/bin/pianissimopi-synth" "$HERE/bin/pianissimopi-connect" "$HERE/bin/pianissimopi-cpu" /usr/local/bin/
# Keep the user's settings on reinstall.
[[ -e /etc/pianissimopi.conf ]] || install -m 0644 "$HERE/config/pianissimopi.conf" /etc/pianissimopi.conf
install -m 0644 "$HERE/systemd/pianissimopi.service" "$HERE/systemd/pianissimopi-connect.service" /etc/systemd/system/
install -m 0644 "$HERE/udev/90-pianissimopi-midi.rules" /etc/udev/rules.d/

systemctl daemon-reload
udevadm control --reload-rules
systemctl enable pianissimopi.service
systemctl restart pianissimopi.service

cat <<EOF

Done. Plug in the SE49 and play.
  Pick an audio output:  aplay -l   then edit AUDIO_DEVICE in /etc/pianissimopi.conf
  Apply changes:         sudo systemctl restart pianissimopi
  Logs:                  journalctl -u pianissimopi -u pianissimopi-connect -f
  Uninstall:             sudo ./uninstall.sh
EOF
