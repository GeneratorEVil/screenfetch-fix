#!/usr/bin/env bash
set -euo pipefail

DEST="/etc/udev/rules.d/99-ignore-lid-switch.rules"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

rm -f "${DEST}"
udevadm control --reload-rules
udevadm trigger --action=change --subsystem-match=input

if systemctl cat upower.service >/dev/null 2>&1; then
  systemctl restart upower || true
fi

echo "Removed ${DEST}"
echo "Reboot recommended to restore lid-close suspend/lock behavior."
