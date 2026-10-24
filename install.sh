#!/usr/bin/env bash
set -euo pipefail

RULE="99-ignore-lid-switch.rules"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/etc/udev/rules.d/${RULE}"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if [[ ! -f "${HERE}/${RULE}" ]]; then
  echo "Missing ${HERE}/${RULE}" >&2
  exit 1
fi

install -m 0644 "${HERE}/${RULE}" "${DEST}"
udevadm control --reload-rules
udevadm trigger --action=change --subsystem-match=input

if systemctl cat upower.service >/dev/null 2>&1; then
  systemctl restart upower || true
fi

echo "Installed ${DEST}"
echo
echo "Lid switch devices:"
for namefile in /sys/class/input/event*/device/name; do
  [[ -r "${namefile}" ]] || continue
  [[ "$(cat "${namefile}")" == "Lid Switch" ]] || continue
  event="$(basename "$(dirname "$(dirname "${namefile}")")")"
  dev="/dev/input/${event}"
  echo "  ${dev}"
  udevadm info --query=property --name="${dev}" | grep -E '^LIBINPUT_IGNORE_DEVICE=' \
    || echo "  LIBINPUT_IGNORE_DEVICE is not set (check the rule)"
done
echo
echo "Reboot recommended: systemd-logind re-opens the switch at boot."
echo "After reboot, recording with the lid closed should work."
