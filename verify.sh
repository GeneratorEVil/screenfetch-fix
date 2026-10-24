#!/usr/bin/env bash
set -uo pipefail

lid="$(awk '{print $2}' /proc/acpi/button/lid/LID/state 2>/dev/null)"
echo "ACPI lid state: ${lid:-n/a}"
printf "UPower LidIsClosed: "
busctl get-property org.freedesktop.UPower /org/freedesktop/UPower \
  org.freedesktop.UPower LidIsClosed 2>/dev/null || echo "n/a"
printf "logind LidClosed: "
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager LidClosed 2>/dev/null || echo "n/a"

echo
echo "Lid switch udev property:"
found=0
for namefile in /sys/class/input/event*/device/name; do
  [[ -r "${namefile}" ]] || continue
  [[ "$(cat "${namefile}")" == "Lid Switch" ]] || continue
  found=1
  event="$(basename "$(dirname "$(dirname "${namefile}")")")"
  dev="/dev/input/${event}"
  echo "  ${dev}"
  udevadm info --query=property --name="${dev}" \
    | grep -E '^(LIBINPUT_IGNORE_DEVICE|ID_INPUT_SWITCH)=' || true
done
[[ ${found} -eq 1 ]] || echo "  no 'Lid Switch' input device found"

echo
echo "Monitors (Mutter DisplayConfig):"
python3 - <<'PY' 2>/dev/null || echo "  python3-gi / Gio not available"
import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
res = bus.call_sync(
    'org.gnome.Mutter.DisplayConfig',
    '/org/gnome/Mutter/DisplayConfig',
    'org.gnome.Mutter.DisplayConfig',
    'GetCurrentState', None, None, Gio.DBusCallFlags.NONE, -1, None)
_, monitors, logical, _ = res.unpack()
for mon in monitors:
    spec, modes = mon[0], mon[1]
    cur = [m for m in modes if m[6].get('is-current')]
    print('  %s %s | current: %s' % (
        spec[0], spec[2],
        [(m[0], m[1], m[2]) for m in cur] or 'NONE'))
PY
