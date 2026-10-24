# screenfetch-fix

Fix screen recording on GNOME/Wayland when the laptop lid is closed and an
external monitor is connected.

## Problem

With the laptop lid closed and an external monitor attached, starting a screen
recording (GNOME's built-in recorder or any portal-based app such as a browser
or Telegram) freezes the desktop or the recording fails. Opening the lid makes
the same recording work.

Typical journal output at the moment of the freeze:

```
systemd-logind: Lid closed.
gnome-shell: meta_monitor_manager_get_logical_monitor_from_number: assertion
             '(unsigned int) number < g_list_length (manager->logical_monitors)' failed
gnome-shell: meta_workspace_get_work_area_for_monitor: assertion
             'logical_monitor != NULL' failed
gnome-shell: value "nan" of type 'gfloat' is invalid or out of range for
             property 'width' of type 'gfloat'
xdg-desktop-portal-gnome: Monitor 'Built-in display' has no configuration
                          which is-current!
kernel: amdgpu ... [drm] *ERROR* dc_dmub_srv_log_diagnostic_data: DMCUB error
        - collecting diagnostic data
pipewire: pw.link: ... negotiating -> error (no more input formats)
```

## Root cause

When the lid closes, GNOME/Mutter disables the internal panel (`eDP-1`). This is
normal, but with an external monitor attached it changes the monitor layout:
the built-in display is still connected while having no current mode.

The screencast source (PipeWire) and `xdg-desktop-portal-gnome`'s display state
tracker expect a valid mode. The stream loses its source, format negotiation
fails, and the shell's monitor list is briefly empty. Extensions such as Zorin
Tiling Shell then compute `NaN` geometry, which can block the shell's main loop
and freeze the whole desktop. The `DMCUB` error is a side effect of disabling
the display pipe, not a GPU fault.

## Fix

A udev rule makes libinput ignore the lid switch:

```
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", \
  ATTRS{name}=="Lid Switch", ENV{LIBINPUT_IGNORE_DEVICE}="1"
```

libinput clients (UPower, systemd-logind, Mutter) no longer see the lid as
closed, so the internal display stays enabled (the panel itself is physically
off) and the monitor layout never changes. Recording then works with the lid
closed.

## Install

```bash
git clone https://github.com/GeneratorEVil/screenfetch-fix.git
cd screenfetch-fix
sudo ./install.sh
sudo reboot
```

`install.sh` copies the rule to `/etc/udev/rules.d/`, reloads udev and restarts
`upower`. A reboot is recommended so `systemd-logind` also re-opens the switch
with the new property. You can try closing the lid before rebooting; if the
internal display still turns off, reboot.

## Verify

```bash
./verify.sh
```

With the lid closed you should see:

- `/proc/acpi/button/lid/LID/state` -> `closed`
- `UPower LidIsClosed` -> `false`
- `LIBINPUT_IGNORE_DEVICE=1` on the `Lid Switch` device
- `eDP-1` still has a current mode in the Mutter monitor list

Then start a recording and confirm it works.

## Trade-offs

- Closing the lid no longer auto-suspends or auto-locks the session. Lock
  manually with `Super+L`; suspend manually from the menu.
- On battery, without an external monitor, the laptop may not sleep on lid
  close. Suspend manually.
- The internal panel stays driven by the GPU (physically off), which costs a
  small amount of power.
- Security: do not close the lid and walk away expecting a locked screen.

## Uninstall

```bash
sudo ./uninstall.sh
sudo reboot
```

## Alternatives

- Keep the lid open while recording.
- Record only the external monitor with an app that survives source removal.
- Disable or update the tiling extension: it produces the `NaN` errors and can
  make the hang worse, but it does not fix the lost screencast source.

## Compatibility

Tested on:

- Lenovo laptop, AMD Renoir/Barcelo (`amdgpu`), external HDMI monitor
- Zorin OS 18.1 (Ubuntu 24.04 base), kernel 6.17
- GNOME Shell 46, Wayland

The fix is generic for GNOME/Mutter + libinput systems. It needs `udev`,
`systemd`, `libinput >= 1.25` (`LIBINPUT_IGNORE_DEVICE`) and `upower`. It should
also work on X11, but it was only tested on Wayland.

The rule matches the standard input device name `Lid Switch`. Check your device
name with:

```bash
grep -H . /sys/class/input/event*/device/name
```

If your lid device has a different name, adjust the `ATTRS{name}` match in
`99-ignore-lid-switch.rules`.

## Publishing

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin git@github.com:GeneratorEVil/screenfetch-fix.git
git push -u origin main
```

## Русский (кратко)

Проблема: при закрытой крышке ноутбука с внешним монитором запись экрана
зависает или ломается, потому что GNOME отключает встроенный экран и
перестраивает раскладку мониторов.

Решение: udev-правило, которое заставляет libinput игнорировать датчик крышки.
Встроенный экран остаётся включённым (физически он погашен), раскладка не
меняется, запись работает.

Установка:

```bash
sudo ./install.sh
sudo reboot
```

Минус: при закрытии крышки не будет автозасыпания и автоблокировки (вручную
`Super+L` и сон работают).

## License

MIT
